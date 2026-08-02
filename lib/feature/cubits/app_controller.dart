import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/process/local_process_runner.dart';
import '../../core/process/process_output_chunk.dart';
import '../../core/terminal/terminal_line_buffer.dart';
import '../classes/overview_snapshot.dart';
import '../classes/server_profile.dart';
import '../packages/command_runner/operation_queue.dart';
import '../packages/local_config/config_paths.dart';
import '../packages/local_config/servers_store.dart';
import '../packages/nginx_template/built_in_templates.dart';
import '../packages/nginx_template/template_manifest.dart';
import '../packages/nginx_template/template_renderer.dart';
import '../packages/overview/overview_parser.dart';
import '../packages/ssh/ssh_command.dart';
import '../packages/ssh/ssh_executor.dart';
import '../packages/ssh/ssh_target.dart';
import '../utils/shell_quote.dart';

class AppController extends ChangeNotifier {
  AppController()
      : _processRunner = LocalProcessRunner(),
        _queue = OperationQueue() {
    _sshExecutor = SshExecutor(processRunner: _processRunner);
    _serversStore = ServersStore(paths: ConfigPaths(homeDirectory: _resolveHomeDirectory()));
  }

  late final SshExecutor _sshExecutor;
  late final ServersStore _serversStore;
  final LocalProcessRunner _processRunner;
  final OperationQueue _queue;
  final TerminalLineBuffer _lineBuffer = TerminalLineBuffer();
  final List<String> _terminalLines = [];
  final List<OperationRecord> _recentOperations = [];

  List<ServerProfile> servers = [];
  SshTarget? target;
  OverviewSnapshot? overviewSnapshot;
  bool isRunning = false;
  bool overviewLoading = false;
  bool terminalExpanded = false;
  String statusLine = '空闲';

  List<String> get terminalLines => List.unmodifiable(_terminalLines);
  List<OperationRecord> get recentOperations => List.unmodifiable(_recentOperations);
  bool get isConnected => target != null;
  List<TemplateManifest> get nginxTemplates => builtInNginxTemplates;

  Future<void> load() async {
    servers = await _serversStore.load();
    notifyListeners();
  }

  Future<void> saveServer(ServerProfile server) async {
    final existingIndex = servers.indexWhere((item) => item.host == server.host && item.user == server.user);
    final nextServers = [...servers];
    if (existingIndex >= 0) {
      nextServers[existingIndex] = server;
    } else {
      nextServers.add(server);
    }

    try {
      await _serversStore.save(nextServers);
    } catch (error) {
      _setStatus('✗ 保存服务器失败: $error');
      return;
    }
    servers = nextServers;
    _setStatus('✓ 已保存服务器 ${server.target}');
    notifyListeners();
  }

  Future<void> deleteServer(ServerProfile server) async {
    servers = [
      for (final item in servers)
        if (item.host != server.host || item.user != server.user) item,
    ];
    await _serversStore.save(servers);
    if (target?.host == server.host && target?.user == server.user) {
      _closeMaster(target!);
      target = null;
      statusLine = '已断开';
    }
    notifyListeners();
  }

  void disconnect() {
    final currentTarget = target;
    target = null;
    statusLine = '已断开';
    notifyListeners();
    if (currentTarget != null) {
      _closeMaster(currentTarget);
    }
  }

  Future<bool> testConnection(String host) async {
    final cleanHost = host.trim();
    if (cleanHost.isEmpty) {
      _setStatus('请输入 Host');
      return false;
    }
    final exitCode = await _runConnectionTest(cleanHost);
    return exitCode == 0;
  }

  Future<void> connect(String host) async {
    final cleanHost = host.trim();
    if (cleanHost.isEmpty) {
      _setStatus('请输入 Host');
      return;
    }
    final nextTarget = SshTarget(host: cleanHost, controlPath: _controlPathFor(cleanHost));
    final exitCode = await _openMasterAndVerify(nextTarget);
    if (exitCode == 0) {
      target = nextTarget;
      await saveServer(_profileForSuccessfulConnect(cleanHost));
      _setStatus('✓ root@$cleanHost 已连接');
    }
  }

  ServerProfile _profileForSuccessfulConnect(String host) {
    return servers.firstWhere(
      (server) => server.host == host && server.user == 'root',
      orElse: () => ServerProfile(name: host, host: host),
    );
  }

  Future<int> _runConnectionTest(String cleanHost) {
    final nextTarget = SshTarget(host: cleanHost);
    return _runOnTarget(
      target: nextTarget,
      summary: '测试连接',
      command: 'echo __myctl_ok__',
      timeout: const Duration(seconds: 12),
    );
  }

  Future<int> _openMasterAndVerify(SshTarget nextTarget) {
    return _queue.run(() async {
      isRunning = true;
      _setStatus('建立 SSH 连接');

      int exitCode;
      try {
        exitCode = await _sshExecutor.openMaster(
          target: nextTarget,
          timeout: const Duration(seconds: 12),
          onOutput: _appendOutput,
        );
        if (exitCode == 0) {
          _appendTerminal('\n\$ ${_displaySshCommand('echo __myctl_ok__')}\n');
          exitCode = await _sshExecutor.run(
            target: nextTarget,
            command: const SshCommand(
              summary: '验证 SSH 连接',
              command: 'echo __myctl_ok__',
              timeout: Duration(seconds: 12),
            ),
            onOutput: _appendOutput,
          );
        }
      } catch (error) {
        exitCode = -1;
        _appendTerminal('$error\n');
      }

      if (exitCode != 0) {
        _closeMaster(nextTarget);
      }
      isRunning = false;
      _setStatus(exitCode == 0 ? '✓ 建立 SSH 连接成功' : '✗ 建立 SSH 连接失败');
      return exitCode;
    });
  }

  Future<void> installPackage(String packageName) {
    final name = packageName.trim();
    if (!_isSafePackageName(name)) {
      _setStatus('请输入有效包名');
      return Future.value();
    }
    return runRemote(
      summary: '安装 $name',
      command: 'apt update && apt install -y ${shellQuote(name)}',
      timeout: const Duration(minutes: 20),
    );
  }

  Future<void> removePackage(String packageName) {
    final name = packageName.trim();
    if (!_isSafePackageName(name)) {
      _setStatus('请输入有效包名');
      return Future.value();
    }
    return runRemote(
      summary: '卸载 $name',
      command: 'apt remove -y ${shellQuote(name)}',
      timeout: const Duration(minutes: 10),
    );
  }

  Future<void> serviceAction(String service, String action) {
    if (!_isSafeServiceName(service)) {
      _setStatus('无效服务名');
      return Future.value();
    }
    final command = switch (action) {
      'start' => 'systemctl start ${shellQuote(service)}',
      'stop' => 'systemctl stop ${shellQuote(service)}',
      'restart' => 'systemctl restart ${shellQuote(service)}',
      'status' => 'systemctl status ${shellQuote(service)} --no-pager',
      'logs' => 'journalctl -u ${shellQuote(service)} --no-pager -n 50',
      _ => null,
    };
    if (command == null) {
      _setStatus('未知服务操作');
      return Future.value();
    }
    return runRemote(summary: '$service $action', command: command);
  }

  Future<void> refreshOverview() async {
    final currentTarget = target;
    if (currentTarget == null) {
      _setStatus('请先连接服务器');
      return;
    }
    overviewLoading = true;
    notifyListeners();

    final output = StringBuffer();
    final exitCode = await _runOnTarget(
      target: currentTarget,
      summary: '刷新概览',
      command: _overviewCommand,
      timeout: const Duration(seconds: 20),
      onOutput: (chunk) {
        if (!chunk.isStdErr) {
          output.write(chunk.text);
        }
      },
    );

    if (exitCode == 0) {
      overviewSnapshot = const OverviewParser().parse(output.toString());
    }
    overviewLoading = false;
    notifyListeners();
  }

  Future<void> listNginxSites() {
    return runRemote(
      summary: '刷新 Nginx 站点',
      command: 'set -e; '
          'echo "[sites-available]"; ls -1 /etc/nginx/sites-available 2>/dev/null || true; '
          'echo; echo "[sites-enabled]"; ls -1 /etc/nginx/sites-enabled 2>/dev/null || true',
    );
  }

  Future<void> enableNginxSite(String site) {
    if (!_isSafeSiteName(site)) {
      _setStatus('无效站点名');
      return Future.value();
    }
    return runRemote(
      summary: '启用站点 $site',
      command: 'ln -sfn /etc/nginx/sites-available/${shellQuote(site)} /etc/nginx/sites-enabled/${shellQuote(site)} && '
          'nginx -t && systemctl reload nginx',
    );
  }

  Future<void> disableNginxSite(String site) {
    if (!_isSafeSiteName(site)) {
      _setStatus('无效站点名');
      return Future.value();
    }
    return runRemote(
      summary: '禁用站点 $site',
      command: 'rm -f /etc/nginx/sites-enabled/${shellQuote(site)} && nginx -t && systemctl reload nginx',
    );
  }

  Future<void> testNginx() {
    return runRemote(summary: 'Nginx 语法检查', command: 'nginx -t');
  }

  Future<void> reloadNginx() {
    return runRemote(summary: 'Reload Nginx', command: 'systemctl reload nginx');
  }

  Future<void> writeNginxSite({
    required String siteName,
    required String config,
  }) {
    final cleanSite = siteName.trim();
    if (!_isSafeSiteName(cleanSite)) {
      _setStatus('站点名只能包含字母、数字、点、下划线和短横线');
      return Future.value();
    }
    if (config.trim().isEmpty) {
      _setStatus('配置内容不能为空');
      return Future.value();
    }

    final encoded = base64.encode(utf8.encode(config));
    final targetFile = '/etc/nginx/sites-available/$cleanSite';
    final command = 'set -e; '
        'target=${shellQuote(targetFile)}; '
        'backup="\$target.myctl.bak.\$(date +%Y%m%d%H%M%S)"; '
        'if [ -f "\$target" ]; then cp "\$target" "\$backup"; fi; '
        'printf %s ${shellQuote(encoded)} | base64 -d > "\$target"; '
        'if ! nginx -t; then '
        '  if [ -n "\${backup:-}" ] && [ -f "\$backup" ]; then cp "\$backup" "\$target"; fi; '
        '  nginx -t || true; '
        '  exit 1; '
        'fi; '
        'ln -sfn "\$target" /etc/nginx/sites-enabled/${shellQuote(cleanSite)}; '
        'systemctl reload nginx';

    return runRemote(
      summary: '写入 Nginx 站点 $cleanSite',
      command: command,
      timeout: const Duration(minutes: 2),
    );
  }

  String renderNginxTemplate(String templateId, Map<String, Object?> variables) {
    final template = switch (templateId) {
      'static_site' => _staticSiteTemplate(variables['enable_logs'] == true),
      'reverse_proxy' => _reverseProxyTemplate,
      _ => '',
    };
    return const TemplateRenderer().render(template: template, variables: variables);
  }

  Future<void> runRemote({
    required String summary,
    required String command,
    Duration? timeout,
  }) async {
    final currentTarget = target;
    if (currentTarget == null) {
      _setStatus('请先连接服务器');
      return;
    }
    await _runOnTarget(target: currentTarget, summary: summary, command: command, timeout: timeout);
  }

  void cancelRunning() {
    if (_processRunner.killActive()) {
      isRunning = false;
      _setStatus('⏹ 操作已取消');
    }
  }

  void toggleTerminal() {
    terminalExpanded = !terminalExpanded;
    notifyListeners();
  }

  Future<int> _runOnTarget({
    required SshTarget target,
    required String summary,
    required String command,
    Duration? timeout,
    void Function(ProcessOutputChunk chunk)? onOutput,
  }) {
    return _queue.run(() async {
      isRunning = true;
      _appendTerminal('\n\$ ${_displaySshCommand(command)}\n');
      _setStatus(summary);

      int exitCode;
      try {
        exitCode = await _sshExecutor.run(
          target: target,
          command: SshCommand(summary: summary, command: command, timeout: timeout),
          onOutput: (chunk) {
            _appendOutput(chunk);
            onOutput?.call(chunk);
          },
        );
      } catch (error) {
        exitCode = -1;
        _appendTerminal('$error\n');
      }

      isRunning = false;
      _recordOperation(summary: summary, command: command, exitCode: exitCode);
      _setStatus(exitCode == 0 ? '✓ $summary 成功' : '✗ $summary 失败');
      return exitCode;
    });
  }

  void _recordOperation({
    required String summary,
    required String command,
    required int exitCode,
  }) {
    _recentOperations.insert(
      0,
      OperationRecord(
        timestamp: DateTime.now(),
        summary: summary,
        command: command,
        exitCode: exitCode,
      ),
    );
    if (_recentOperations.length > 10) {
      _recentOperations.removeRange(10, _recentOperations.length);
    }
  }

  String _displaySshCommand(String command) {
    return command;
  }

  void _closeMaster(SshTarget target) {
    _sshExecutor.closeMaster(target: target, onOutput: _appendOutput).catchError((Object _) => 255);
  }

  String _controlPathFor(String host) {
    final user = 'root';
    final identity = '$user@$host';
    return '/tmp/ssh-depot-${_stableHash(identity)}.sock';
  }

  String _stableHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }

  void _appendOutput(ProcessOutputChunk chunk) {
    _appendTerminal(chunk.text);
  }

  void _appendTerminal(String text) {
    _terminalLines.add(text);
    _lineBuffer.append(text);
    if (isRunning && _lineBuffer.lastVisibleLine.isNotEmpty) {
      statusLine = _lineBuffer.lastVisibleLine;
    }
    notifyListeners();
  }

  void _setStatus(String value) {
    statusLine = value;
    notifyListeners();
  }

  bool _isSafePackageName(String value) {
    return RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9+._:-]*$').hasMatch(value);
  }

  bool _isSafeServiceName(String value) {
    return RegExp(r'^[a-zA-Z0-9_.@:-]+$').hasMatch(value);
  }

  bool _isSafeSiteName(String value) {
    return RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*$').hasMatch(value);
  }

  static String _resolveHomeDirectory() {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty && !home.contains('/Library/Containers/')) {
      return home;
    }

    if (Platform.isMacOS) {
      final user = Platform.environment['USER'];
      if (user != null && user.isNotEmpty) {
        return '/Users/$user';
      }
    }

    return home ?? Directory.current.path;
  }
}

String _staticSiteTemplate(bool enableLogs) {
  return '''
server {
    listen 80;
    server_name {{domain}};
    root {{root_path}};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
${enableLogs ? '''
    access_log /var/log/nginx/{{domain}}_access.log;
    error_log /var/log/nginx/{{domain}}_error.log;
''' : ''}
}
''';
}

const _overviewCommand = r'''
set -e
if command -v lsb_release >/dev/null 2>&1; then
  distribution=$(lsb_release -ds 2>/dev/null)
else
  . /etc/os-release
  distribution=${PRETTY_NAME:-unknown}
fi
kernel=$(uname -r 2>/dev/null || true)
uptime_text=$(uptime -p 2>/dev/null || uptime 2>/dev/null || true)
read _ cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq cpu_softirq cpu_steal _ < /proc/stat
cpu_idle_1=$((cpu_idle + cpu_iowait))
cpu_total_1=$((cpu_user + cpu_nice + cpu_system + cpu_idle + cpu_iowait + cpu_irq + cpu_softirq + cpu_steal))
sleep 0.2
read _ cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq cpu_softirq cpu_steal _ < /proc/stat
cpu_idle_2=$((cpu_idle + cpu_iowait))
cpu_total_2=$((cpu_user + cpu_nice + cpu_system + cpu_idle + cpu_iowait + cpu_irq + cpu_softirq + cpu_steal))
cpu_total_delta=$((cpu_total_2 - cpu_total_1))
cpu_idle_delta=$((cpu_idle_2 - cpu_idle_1))
if [ "$cpu_total_delta" -gt 0 ]; then
  cpu=$((100 * (cpu_total_delta - cpu_idle_delta) / cpu_total_delta))
else
  cpu=0
fi
memory=$(free -m | awk '/^Mem:/ { if ($2 > 0) printf "%.0f", (($2 - $7) * 100 / $2); }')
disk=$(df -P / | awk 'NR==2 { gsub(/%/, "", $5); print $5; }')
printf "distribution=%s\n" "$distribution"
printf "kernel=%s\n" "$kernel"
printf "uptime=%s\n" "$uptime_text"
printf "cpu=%s\n" "$cpu"
printf "memory=%s\n" "${memory:-0}"
printf "disk=%s\n" "${disk:-0}"
for svc in nginx mysql redis docker; do
  status=$(systemctl is-active "$svc" 2>/dev/null || true)
  enabled=$(systemctl is-enabled "$svc" 2>/dev/null || true)
  printf "service=%s;status=%s;enabled=%s\n" "$svc" "${status:-unknown}" "${enabled:-unknown}"
done
''';

const _reverseProxyTemplate = '''
server {
    listen 80;
    server_name {{domain}};

    location / {
        proxy_pass http://{{upstream_host}}:{{upstream_port}};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
''';
