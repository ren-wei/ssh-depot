import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/process/local_process_runner.dart';
import '../../core/process/process_output_chunk.dart';
import '../../core/terminal/terminal_line_buffer.dart';
import '../classes/nginx_site.dart';
import '../classes/nginx_template_definition.dart';
import '../classes/overview_snapshot.dart';
import '../classes/server_profile.dart';
import '../packages/command_runner/operation_queue.dart';
import '../packages/local_config/config_paths.dart';
import '../packages/local_config/nginx_templates_store.dart';
import '../packages/local_config/service_preferences_store.dart';
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
    final paths = ConfigPaths(homeDirectory: _resolveHomeDirectory());
    _serversStore = ServersStore(paths: paths);
    _servicePreferencesStore = ServicePreferencesStore(paths: paths);
    _nginxTemplatesStore = NginxTemplatesStore(paths: paths);
  }

  late final SshExecutor _sshExecutor;
  late final ServersStore _serversStore;
  late final ServicePreferencesStore _servicePreferencesStore;
  late final NginxTemplatesStore _nginxTemplatesStore;
  final LocalProcessRunner _processRunner;
  final OperationQueue _queue;
  final TerminalLineBuffer _lineBuffer = TerminalLineBuffer();
  final List<String> _terminalLines = [];
  final List<OperationRecord> _recentOperations = [];

  List<ServerProfile> servers = [];
  List<String> managedServices = const ['nginx.service'];
  List<NginxSite> nginxSites = const [];
  List<NginxCertificateInfo> nginxCertificates = const [];
  List<NginxTemplateDefinition> customNginxTemplates = const [];
  Map<String, ServiceSnapshot> serviceSnapshots = const {};
  SshTarget? target;
  OverviewSnapshot? overviewSnapshot;
  String? serviceLogsService;
  String serviceLogsOutput = '';
  bool isRunning = false;
  bool overviewLoading = false;
  bool terminalExpanded = false;
  String statusLine = '空闲';

  List<String> get terminalLines => List.unmodifiable(_terminalLines);
  List<OperationRecord> get recentOperations => List.unmodifiable(_recentOperations);
  bool get isConnected => target != null;
  List<TemplateManifest> get nginxTemplates => builtInNginxTemplates;
  List<NginxTemplateDefinition> get websiteTemplates => [
        ..._builtInWebsiteTemplates,
        ...customNginxTemplates,
      ];

  Future<void> load() async {
    servers = await _serversStore.load();
    managedServices = const ['nginx.service'];
    customNginxTemplates = await _nginxTemplatesStore.load();
    notifyListeners();
  }

  Future<void> addManagedService(String service) async {
    final cleanService = _serviceUnitName(service);
    if (!_isSafeServiceName(cleanService)) {
      _setStatus('无效服务名');
      return;
    }
    if (managedServices.contains(cleanService)) {
      _setStatus('服务已存在');
      return;
    }

    managedServices = [...managedServices, cleanService];
    await _saveManagedServices();
    _setStatus('✓ 已添加服务 ${serviceDisplayName(cleanService)}');
    if (isConnected) {
      await refreshServiceStatus(cleanService);
    }
  }

  Future<void> removeManagedService(String service) async {
    managedServices = [
      for (final item in managedServices)
        if (item != service) item,
    ];
    if (managedServices.isEmpty) {
      managedServices = const ['nginx.service'];
    }
    serviceSnapshots = {
      for (final entry in serviceSnapshots.entries)
        if (managedServices.contains(entry.key)) entry.key: entry.value,
    };
    overviewSnapshot = _filterOverviewServices(overviewSnapshot);
    await _saveManagedServices();
    _setStatus('✓ 已移除服务 ${serviceDisplayName(service)}');
  }

  Future<List<String>> searchRemoteServices() async {
    final currentTarget = target;
    if (currentTarget == null) {
      _setStatus('请先连接服务器');
      return const [];
    }

    final output = StringBuffer();
    final exitCode = await _runOnTarget(
      target: currentTarget,
      summary: '搜索服务',
      command: 'systemctl list-unit-files --type=service --no-pager --no-legend; '
          'systemctl list-units --type=service --all --no-pager --no-legend',
      timeout: const Duration(seconds: 20),
      onOutput: (chunk) {
        if (!chunk.isStdErr) {
          output.write(chunk.text);
        }
      },
    );

    if (exitCode != 0) {
      return const [];
    }
    return _parseSystemdServices(output.toString());
  }

  Future<void> refreshServiceStatus(String service) async {
    final currentTarget = target;
    if (currentTarget == null) {
      _setStatus('请先连接服务器');
      return;
    }
    final serviceUnit = _serviceUnitName(service);
    if (!_isSafeServiceName(serviceUnit)) {
      _setStatus('无效服务名');
      return;
    }

    final output = StringBuffer();
    final exitCode = await _runOnTarget(
      target: currentTarget,
      summary: '获取 ${serviceDisplayName(serviceUnit)} 状态',
      command: 'status=\$(systemctl is-active ${shellQuote(serviceUnit)} 2>/dev/null || true); '
          'enabled=\$(systemctl is-enabled ${shellQuote(serviceUnit)} 2>/dev/null || true); '
          'printf "service=%s;status=%s;enabled=%s\\n" ${shellQuote(serviceUnit)} "\${status:-unknown}" "\${enabled:-unknown}"',
      timeout: const Duration(seconds: 12),
      onOutput: (chunk) {
        if (!chunk.isStdErr) {
          output.write(chunk.text);
        }
      },
    );

    if (exitCode != 0) {
      return;
    }
    final snapshot = _parseServiceSnapshot(output.toString());
    if (snapshot == null) {
      return;
    }
    serviceSnapshots = {...serviceSnapshots, snapshot.name: snapshot};
    overviewSnapshot = _replaceOverviewService(overviewSnapshot, snapshot);
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
      _closeMaster(target!, appendOutput: false);
      target = null;
      _clearConnectionRuntimeCache();
      statusLine = '已断开';
    }
    notifyListeners();
  }

  void disconnect() {
    final currentTarget = target;
    target = null;
    _clearConnectionRuntimeCache();
    statusLine = '已断开';
    notifyListeners();
    if (currentTarget != null) {
      _closeMaster(currentTarget, appendOutput: false);
    }
  }

  Future<bool> testConnection(String host, {String user = 'root'}) async {
    final cleanHost = host.trim();
    final cleanUser = user.trim().isEmpty ? 'root' : user.trim();
    if (cleanHost.isEmpty) {
      _setStatus('请输入 Host');
      return false;
    }
    final exitCode = await _runConnectionTest(cleanHost, cleanUser);
    return exitCode == 0;
  }

  Future<void> connect(String host, {String user = 'root'}) async {
    final cleanHost = host.trim();
    final cleanUser = user.trim().isEmpty ? 'root' : user.trim();
    if (cleanHost.isEmpty) {
      _setStatus('请输入 Host');
      return;
    }
    final previousTarget = target;
    if (previousTarget != null) {
      _closeMaster(previousTarget, appendOutput: false);
    }
    target = null;
    _clearConnectionRuntimeCache();
    final nextTarget = SshTarget(
      host: cleanHost,
      user: cleanUser,
      controlPath: _controlPathFor(cleanHost, cleanUser),
    );
    final exitCode = await _openMasterAndVerify(nextTarget);
    if (exitCode == 0) {
      managedServices = _normalizeManagedServices(await _servicePreferencesStore.load(nextTarget.address));
      target = nextTarget;
      await saveServer(_profileForSuccessfulConnect(cleanHost, cleanUser));
      _setStatus('✓ $cleanUser@$cleanHost 已连接');
    } else {
      managedServices = const ['nginx.service'];
    }
  }

  ServerProfile _profileForSuccessfulConnect(String host, String user) {
    return servers.firstWhere(
      (server) => server.host == host && server.user == user,
      orElse: () => ServerProfile(name: host, host: host, user: user),
    );
  }

  Future<int> _runConnectionTest(String cleanHost, String cleanUser) {
    final nextTarget = SshTarget(host: cleanHost, user: cleanUser);
    return _runOnTarget(
      target: nextTarget,
      summary: '测试连接',
      command: 'echo __ssh-depot_ok__',
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
          _appendTerminal('\n\$ ${_displaySshCommand('echo __ssh-depot_ok__')}\n');
          exitCode = await _sshExecutor.run(
            target: nextTarget,
            command: const SshCommand(
              summary: '验证 SSH 连接',
              command: 'echo __ssh-depot_ok__',
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

  Future<void> serviceAction(String service, String action) async {
    final currentTarget = target;
    if (currentTarget == null) {
      _setStatus('请先连接服务器');
      return;
    }
    final serviceUnit = _serviceUnitName(service);
    if (!_isSafeServiceName(serviceUnit)) {
      _setStatus('无效服务名');
      return;
    }
    if (action == 'logs') {
      await fetchServiceLogs(serviceUnit);
      return;
    }
    final command = switch (action) {
      'start' => 'systemctl start ${shellQuote(serviceUnit)}',
      'stop' => 'systemctl stop ${shellQuote(serviceUnit)}',
      'restart' => 'systemctl restart ${shellQuote(serviceUnit)}',
      'status' => 'systemctl status ${shellQuote(serviceUnit)} --no-pager',
      _ => null,
    };
    if (command == null) {
      _setStatus('未知服务操作');
      return;
    }
    final exitCode = await _runOnTarget(
      target: currentTarget,
      summary: '${serviceDisplayName(serviceUnit)} $action',
      command: command,
    );
    if (action == 'start' || action == 'stop' || action == 'restart') {
      if (exitCode == 0) {
        _applyExpectedServiceStatus(serviceUnit, action);
      }
      await refreshServiceStatus(serviceUnit);
      await fetchServiceLogs(serviceUnit);
    }
  }

  Future<void> fetchServiceLogs(String service) async {
    final currentTarget = target;
    if (currentTarget == null) {
      _setStatus('请先连接服务器');
      return;
    }
    final serviceUnit = _serviceUnitName(service);
    if (!_isSafeServiceName(serviceUnit)) {
      _setStatus('无效服务名');
      return;
    }
    serviceLogsService = serviceUnit;
    serviceLogsOutput = '';
    notifyListeners();

    final output = StringBuffer();
    final exitCode = await _runOnTarget(
      target: currentTarget,
      summary: '查看 ${serviceDisplayName(serviceUnit)} 日志',
      command: _serviceLogsCommand(serviceUnit),
      onOutput: (chunk) {
        output.write(chunk.text);
        serviceLogsOutput = output.toString();
        notifyListeners();
      },
    );

    if (output.isEmpty) {
      serviceLogsOutput = exitCode == 0 ? '暂无日志输出' : '查看日志失败';
      notifyListeners();
    }
  }

  String _serviceLogsCommand(String serviceUnit) {
    final unit = shellQuote(serviceUnit);
    if (serviceDisplayName(serviceUnit) != 'nginx') {
      return 'journalctl -u $unit --no-pager -n 80';
    }
    return 'echo "[systemd journal]"; '
        'journalctl -u $unit --no-pager -n 80; '
        'echo; echo "[nginx error.log]"; '
        'if [ -f /var/log/nginx/error.log ]; then tail -n 80 /var/log/nginx/error.log; else echo "未找到 /var/log/nginx/error.log"; fi; '
        'echo; echo "[nginx access.log]"; '
        'if [ -f /var/log/nginx/access.log ]; then tail -n 80 /var/log/nginx/access.log; else echo "未找到 /var/log/nginx/access.log"; fi';
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
      command: _overviewCommandFor(managedServices),
      timeout: const Duration(seconds: 20),
      onOutput: (chunk) {
        if (!chunk.isStdErr) {
          output.write(chunk.text);
        }
      },
    );

    if (exitCode == 0) {
      overviewSnapshot = const OverviewParser().parse(output.toString());
      serviceSnapshots = {
        ...serviceSnapshots,
        for (final service in overviewSnapshot!.services) service.name: service,
      };
    }
    overviewLoading = false;
    notifyListeners();
  }

  Future<void> refreshNginxSites() async {
    final result = await _runCaptureRemote(
      summary: '刷新网站列表',
      command: 'echo "__sites_available__"; '
          'find /etc/nginx/sites-available -maxdepth 1 -type f -printf "%f\\n" 2>/dev/null || true; '
          'echo "__sites_enabled__"; '
          'find /etc/nginx/sites-enabled -maxdepth 1 \\( -type f -o -type l \\) -printf "%f\\n" 2>/dev/null || true; '
          'echo "__site_domains__"; '
          'for sitefile in /etc/nginx/sites-available/*; do '
          '  [ -f "\$sitefile" ] || continue; '
          '  sitename=\$(basename "\$sitefile"); '
          '  domains=\$(sed -n "s/^[[:space:]]*server_name[[:space:]]\\+\\([^;]*\\);.*/\\1/p" "\$sitefile" '
          '    | tr "\\n" " " | tr -s " " | sed "s/^ //;s/ \$//" || true); '
          '  printf "%s|%s\\n" "\$sitename" "\$domains"; '
          'done; '
          'echo "__certificates__"; '
          'for certdir in /etc/letsencrypt/live/*; do '
          '  [ -d "\$certdir" ] || continue; '
          '  name=\$(basename "\$certdir"); fullchain="\$certdir/fullchain.pem"; '
          '  [ -f "\$fullchain" ] || continue; '
          '  end_date=\$(openssl x509 -in "\$fullchain" -noout -enddate 2>/dev/null | cut -d= -f2- || true); '
          '  end_epoch=\$(date -d "\$end_date" +%s 2>/dev/null || echo 0); '
          '  issuer=\$(openssl x509 -in "\$fullchain" -noout -issuer 2>/dev/null | sed "s/^issuer=//" || true); '
          '  names=\$(openssl x509 -in "\$fullchain" -noout -ext subjectAltName 2>/dev/null '
          '    | grep -o "DNS:[^, ]*" | sed "s/^DNS://" | tr "\\n" " " | tr -s " " | sed "s/^ //;s/ \$//" || true); '
          '  private_key="\$certdir/privkey.pem"; '
          '  printf "%s|%s|%s|%s|%s|%s\\n" "\$name" "\$end_epoch" "\$issuer" "\$fullchain" "\$private_key" "\$names"; '
          'done',
      timeout: const Duration(seconds: 20),
    );
    if (result == null || !result.succeeded) {
      return;
    }
    nginxSites = _parseNginxSites(result.output);
    notifyListeners();
  }

  Future<void> listNginxSites() {
    return refreshNginxSites();
  }

  Future<void> enableNginxSite(String site) async {
    if (!_isSafeSiteName(site)) {
      _setStatus('无效站点名');
      return Future.value();
    }
    await runRemote(
      summary: '启用网站 $site',
      command: 'ln -sfn /etc/nginx/sites-available/${shellQuote(site)} /etc/nginx/sites-enabled/${shellQuote(site)} && '
          'nginx -t && systemctl reload nginx',
    );
    await refreshNginxSites();
  }

  Future<void> disableNginxSite(String site) async {
    if (!_isSafeSiteName(site)) {
      _setStatus('无效站点名');
      return Future.value();
    }
    await runRemote(
      summary: '禁用网站 $site',
      command: 'rm -f /etc/nginx/sites-enabled/${shellQuote(site)} && nginx -t && systemctl reload nginx',
    );
    await refreshNginxSites();
  }

  Future<void> testNginx() {
    return runRemote(summary: '网站语法检查', command: 'nginx -t');
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
        'backup="\$target.ssh-depot.bak.\$(date +%Y%m%d%H%M%S)"; '
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
      summary: '写入网站配置 $cleanSite',
      command: command,
      timeout: const Duration(minutes: 2),
    );
  }

  Future<String?> readNginxSiteConfig(String site) async {
    if (!_isSafeSiteName(site)) {
      _setStatus('无效站点名');
      return null;
    }
    final targetPrefix = _nginxSiteTargetPrefix(site);
    final result = await _runCaptureRemote(
      summary: '读取网站配置 $site',
      command: '$targetPrefix cat "\$target"',
      timeout: const Duration(seconds: 12),
    );
    if (result == null || !result.succeeded) {
      return null;
    }
    return result.output;
  }

  Future<RemoteCommandResult?> testNginxSiteConfig({
    required String siteName,
    required String config,
  }) async {
    final cleanSite = siteName.trim();
    if (!_isSafeSiteName(cleanSite)) {
      _setStatus('无效站点名');
      return null;
    }
    if (config.trim().isEmpty) {
      _setStatus('配置内容不能为空');
      return null;
    }

    final encoded = base64.encode(utf8.encode(config));
    final targetPrefix = _nginxSiteTargetPrefix(cleanSite);
    final command = 'set -e; '
        '$targetPrefix '
        'backup="\$target.ssh-depot.test.\$(date +%Y%m%d%H%M%S)"; '
        'had_original=0; '
        'if [ -f "\$target" ]; then had_original=1; cp "\$target" "\$backup"; fi; '
        'restore() { if [ "\$had_original" = "1" ]; then cp "\$backup" "\$target"; else rm -f "\$target"; fi; rm -f "\$backup"; }; '
        'printf %s ${shellQuote(encoded)} | base64 -d > "\$target"; '
        'if nginx -t; then restore; exit 0; else code=\$?; restore; exit "\$code"; fi';
    return _runCaptureRemote(
      summary: '检查网站配置 $cleanSite',
      command: command,
      timeout: const Duration(minutes: 2),
    );
  }

  Future<RemoteCommandResult?> saveNginxSiteConfig({
    required String siteName,
    required String config,
  }) async {
    final cleanSite = siteName.trim();
    if (!_isSafeSiteName(cleanSite)) {
      _setStatus('无效站点名');
      return null;
    }
    if (config.trim().isEmpty) {
      _setStatus('配置内容不能为空');
      return null;
    }

    final encoded = base64.encode(utf8.encode(config));
    final targetPrefix = _nginxSiteTargetPrefix(cleanSite);
    final command = 'set -e; '
        '$targetPrefix '
        'backup="\$target.ssh-depot.bak.\$(date +%Y%m%d%H%M%S)"; '
        'if [ -f "\$target" ]; then cp "\$target" "\$backup"; fi; '
        'printf %s ${shellQuote(encoded)} | base64 -d > "\$target"; '
        'if ! nginx -t; then '
        '  if [ -f "\$backup" ]; then cp "\$backup" "\$target"; else rm -f "\$target"; fi; '
        '  nginx -t || true; '
        '  exit 1; '
        'fi; '
        'systemctl reload nginx';
    final result = await _runCaptureRemote(
      summary: '保存网站配置 $cleanSite',
      command: command,
      timeout: const Duration(minutes: 2),
    );
    await refreshNginxSites();
    return result;
  }

  Future<void> deleteNginxSite(String site) async {
    if (!_isSafeSiteName(site)) {
      _setStatus('无效站点名');
      return;
    }
    await runRemote(
      summary: '删除网站 $site',
      command: 'rm -f /etc/nginx/sites-enabled/${shellQuote(site)} '
          '/etc/nginx/sites-available/${shellQuote(site)} && nginx -t && systemctl reload nginx',
      timeout: const Duration(minutes: 2),
    );
    await refreshNginxSites();
  }

  Future<RemoteCommandResult?> certificateDetails(String certName) {
    final cleanCertName = certName.trim();
    if (!_isSafeSiteName(cleanCertName)) {
      _setStatus('无效证书名称');
      return Future.value();
    }
    return _runCaptureRemote(
      summary: '查看证书 $cleanCertName',
      command: 'fullchain=/etc/letsencrypt/live/${shellQuote(cleanCertName)}/fullchain.pem; '
          'if [ ! -f "\$fullchain" ]; then echo "未找到证书: \$fullchain"; exit 1; fi; '
          'openssl x509 -in "\$fullchain" -noout -subject -issuer -dates -serial -ext subjectAltName',
      timeout: const Duration(seconds: 12),
    );
  }

  Future<RemoteCommandResult?> checkCertificateEnvironment() {
    return _runCaptureRemote(
      summary: '检查证书环境',
      command: 'set +e; '
          'echo "[certbot]"; command -v certbot && certbot --version || echo "certbot 未安装"; '
          'echo; echo "[certbot plugins]"; certbot plugins 2>/dev/null || true; '
          'echo; echo "[nginx]"; nginx -t; '
          'echo; echo "[nginx status]"; systemctl is-active nginx 2>/dev/null || true; '
          'echo; echo "[listen 80/443]"; ss -lntp 2>/dev/null | grep -E ":(80|443)[[:space:]]" || true',
      timeout: const Duration(seconds: 20),
    );
  }

  Future<RemoteCommandResult?> requestCertificate({
    required String domain,
    required String email,
    required bool useWebroot,
    required String webroot,
  }) async {
    final domains = _parseCertificateRequestDomains(domain);
    if (domains.isEmpty) {
      _setStatus('无效域名');
      return null;
    }
    if (email.trim().isEmpty) {
      _setStatus('请输入邮箱');
      return null;
    }
    if (useWebroot && webroot.trim().isEmpty) {
      _setStatus('请输入 Webroot 路径');
      return null;
    }
    final domainArgs = domains.map((domain) => '-d ${shellQuote(domain)}').join(' ');
    final command = useWebroot
        ? 'certbot certonly --webroot -w ${shellQuote(webroot.trim())} $domainArgs '
            '--non-interactive --agree-tos -m ${shellQuote(email.trim())}'
        : 'certbot --nginx $domainArgs --non-interactive --agree-tos -m ${shellQuote(email.trim())}';
    final result = await _runCaptureRemote(
      summary: '申请证书 ${domains.first}',
      command: command,
      timeout: const Duration(minutes: 5),
    );
    await refreshNginxSites();
    return result;
  }

  Future<RemoteCommandResult?> renewCertificate(String certName, {bool dryRun = false}) async {
    final cleanCertName = certName.trim();
    if (!_isSafeSiteName(cleanCertName)) {
      _setStatus('无效证书名称');
      return null;
    }
    final result = await _runCaptureRemote(
      summary: dryRun ? '测试续期证书 $cleanCertName' : '续期证书 $cleanCertName',
      command: 'certbot renew --cert-name ${shellQuote(cleanCertName)}${dryRun ? ' --dry-run' : ''}',
      timeout: const Duration(minutes: 5),
    );
    await refreshNginxSites();
    return result;
  }

  Future<RemoteCommandResult?> updateCertificateDomains({
    required String certName,
    required List<String> domains,
    required bool useWebroot,
    required String webroot,
  }) async {
    final cleanCertName = certName.trim();
    final cleanDomains = {
      for (final domain in domains) ..._parseCertificateRequestDomains(domain),
    }.toList();
    if (!_isSafeSiteName(cleanCertName)) {
      _setStatus('无效证书名称');
      return null;
    }
    if (cleanDomains.isEmpty) {
      _setStatus('证书至少需要保留一个域名');
      return null;
    }
    if (useWebroot && webroot.trim().isEmpty) {
      _setStatus('请输入 Webroot 路径');
      return null;
    }
    final domainArgs = cleanDomains.map((domain) => '-d ${shellQuote(domain)}').join(' ');
    final command = useWebroot
        ? 'certbot certonly --webroot -w ${shellQuote(webroot.trim())} --cert-name ${shellQuote(cleanCertName)} '
            '$domainArgs --non-interactive'
        : 'certbot --nginx --cert-name ${shellQuote(cleanCertName)} $domainArgs --non-interactive';
    final result = await _runCaptureRemote(
      summary: '更新证书域名 $cleanCertName',
      command: command,
      timeout: const Duration(minutes: 5),
    );
    await refreshNginxSites();
    return result;
  }

  Future<RemoteCommandResult?> deleteCertificate(String certName) async {
    final cleanCertName = certName.trim();
    if (!_isSafeSiteName(cleanCertName)) {
      _setStatus('无效证书名称');
      return null;
    }
    final result = await _runCaptureRemote(
      summary: '删除证书 $cleanCertName',
      command: 'certbot delete --cert-name ${shellQuote(cleanCertName)} --non-interactive',
      timeout: const Duration(minutes: 2),
    );
    await refreshNginxSites();
    return result;
  }

  Future<void> createNginxSite({
    required String siteName,
    required String config,
  }) async {
    final result = await saveNginxSiteConfig(siteName: siteName, config: config);
    if (result?.succeeded == true) {
      await refreshNginxSites();
    }
  }

  Future<void> saveWebsiteTemplate({
    required String name,
    required String type,
    required String description,
    required String content,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _setStatus('请输入模板名称');
      return;
    }
    if (content.trim().isEmpty) {
      _setStatus('模板内容不能为空');
      return;
    }
    final template = NginxTemplateDefinition(
      id: 'custom_${_stableHash('$cleanName|${DateTime.now().microsecondsSinceEpoch}')}',
      name: cleanName,
      type: type.trim().isEmpty ? '自定义' : type.trim(),
      description: description.trim().isEmpty ? null : description.trim(),
      content: content,
    );
    try {
      await _nginxTemplatesStore.save(template);
      customNginxTemplates = await _nginxTemplatesStore.load();
      _setStatus('✓ 已保存模板 $cleanName');
      notifyListeners();
    } catch (error) {
      _setStatus('✗ 保存模板失败: $error');
    }
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

  Future<RemoteCommandResult?> _runCaptureRemote({
    required String summary,
    required String command,
    Duration? timeout,
  }) async {
    final currentTarget = target;
    if (currentTarget == null) {
      _setStatus('请先连接服务器');
      return null;
    }

    final output = StringBuffer();
    final exitCode = await _runOnTarget(
      target: currentTarget,
      summary: summary,
      command: command,
      timeout: timeout,
      onOutput: (chunk) => output.write(chunk.text),
    );
    return RemoteCommandResult(exitCode: exitCode, output: output.toString());
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

  void _closeMaster(SshTarget target, {bool appendOutput = true}) {
    _sshExecutor
        .closeMaster(
          target: target,
          onOutput: appendOutput ? _appendOutput : (_) {},
        )
        .catchError((Object _) => 255);
  }

  String _controlPathFor(String host, String user) {
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

  String _serviceUnitName(String service) {
    final cleanService = service.trim();
    if (cleanService.isEmpty || cleanService.endsWith('.service')) {
      return cleanService;
    }
    return '$cleanService.service';
  }

  List<String> _normalizeManagedServices(List<String> services) {
    final normalized = [
      for (final service in services) _serviceUnitName(service),
    ].where(_isSafeServiceName).toSet().toList();
    return normalized.isEmpty ? const ['nginx.service'] : normalized;
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

  Future<void> _saveManagedServices() async {
    final currentTarget = target;
    if (currentTarget == null) {
      notifyListeners();
      return;
    }
    try {
      await _servicePreferencesStore.save(currentTarget.address, managedServices);
    } catch (error) {
      _setStatus('✗ 保存服务列表失败: $error');
    }
    notifyListeners();
  }

  void _clearConnectionRuntimeCache() {
    _terminalLines.clear();
    _lineBuffer.clear();
    _recentOperations.clear();
    nginxSites = const [];
    nginxCertificates = const [];
    serviceSnapshots = const {};
    overviewSnapshot = null;
    serviceLogsService = null;
    serviceLogsOutput = '';
    overviewLoading = false;
    terminalExpanded = false;
  }

  OverviewSnapshot? _filterOverviewServices(OverviewSnapshot? snapshot) {
    if (snapshot == null) {
      return null;
    }
    return OverviewSnapshot(
      distribution: snapshot.distribution,
      kernel: snapshot.kernel,
      uptime: snapshot.uptime,
      cpuPercent: snapshot.cpuPercent,
      memoryPercent: snapshot.memoryPercent,
      diskPercent: snapshot.diskPercent,
      services: [
        for (final service in snapshot.services)
          if (managedServices.contains(service.name)) service,
      ],
    );
  }

  List<String> _parseSystemdServices(String output) {
    final services = <String>{};
    for (final line in const LineSplitter().convert(output)) {
      final columns = line.trim().split(RegExp(r'\s+'));
      if (columns.isEmpty) {
        continue;
      }
      final unit = columns.first.trim();
      if (!unit.endsWith('.service')) {
        continue;
      }
      if (_isSafeServiceName(unit)) {
        services.add(unit);
      }
    }
    final sorted = services.toList()..sort();
    return sorted;
  }

  ServiceSnapshot? _parseServiceSnapshot(String output) {
    for (final rawLine in const LineSplitter().convert(output)) {
      final line = rawLine.trim();
      if (!line.startsWith('service=')) {
        continue;
      }

      String? name;
      ServiceStatus status = ServiceStatus.unknown;
      bool? enabled;
      for (final part in line.split(';')) {
        final separator = part.indexOf('=');
        if (separator <= 0) {
          continue;
        }
        final key = part.substring(0, separator);
        final value = part.substring(separator + 1);
        switch (key) {
          case 'service':
            name = value;
          case 'status':
            status = switch (value) {
              'active' => ServiceStatus.active,
              'inactive' => ServiceStatus.inactive,
              'failed' => ServiceStatus.failed,
              _ => ServiceStatus.unknown,
            };
          case 'enabled':
            enabled = switch (value) {
              'enabled' => true,
              'disabled' => false,
              _ => null,
            };
        }
      }
      if (name != null && name.isNotEmpty) {
        return ServiceSnapshot(name: name, status: status, enabled: enabled);
      }
    }
    return null;
  }

  OverviewSnapshot? _replaceOverviewService(OverviewSnapshot? snapshot, ServiceSnapshot service) {
    if (snapshot == null) {
      return null;
    }
    final services = [
      for (final item in snapshot.services)
        if (item.name != service.name) item,
      service,
    ];
    services.sort((a, b) => managedServices.indexOf(a.name).compareTo(managedServices.indexOf(b.name)));
    return OverviewSnapshot(
      distribution: snapshot.distribution,
      kernel: snapshot.kernel,
      uptime: snapshot.uptime,
      cpuPercent: snapshot.cpuPercent,
      memoryPercent: snapshot.memoryPercent,
      diskPercent: snapshot.diskPercent,
      services: services,
    );
  }

  void _applyExpectedServiceStatus(String serviceUnit, String action) {
    final previous = serviceSnapshots[serviceUnit];
    final status = switch (action) {
      'stop' => ServiceStatus.inactive,
      'start' || 'restart' => ServiceStatus.active,
      _ => previous?.status ?? ServiceStatus.unknown,
    };
    final snapshot = ServiceSnapshot(
      name: serviceUnit,
      status: status,
      enabled: previous?.enabled,
    );
    serviceSnapshots = {...serviceSnapshots, serviceUnit: snapshot};
    overviewSnapshot = _replaceOverviewService(overviewSnapshot, snapshot);
    notifyListeners();
  }

  List<NginxSite> _parseNginxSites(String output) {
    final available = <String>{};
    final enabled = <String>{};
    final siteDomains = <String, List<String>>{};
    final certificates = <NginxCertificateInfo>[];
    var section = '';

    for (final rawLine in const LineSplitter().convert(output)) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      if (line == '__sites_available__' ||
          line == '__sites_enabled__' ||
          line == '__site_domains__' ||
          line == '__certificates__') {
        section = line;
        continue;
      }
      if (section == '__sites_available__') {
        if (!_isSafeSiteName(line)) {
          continue;
        }
        available.add(line);
      } else if (section == '__sites_enabled__') {
        if (!_isSafeSiteName(line)) {
          continue;
        }
        enabled.add(line);
      } else if (section == '__site_domains__') {
        final parts = line.split('|');
        if (parts.isEmpty || !_isSafeSiteName(parts.first)) {
          continue;
        }
        siteDomains[parts.first] = _parseDomainList(parts.length > 1 ? parts[1] : '');
      } else if (section == '__certificates__') {
        final certificate = _parseCertificateLine(line);
        if (certificate != null) {
          certificates.add(certificate);
        }
      }
    }

    nginxCertificates = certificates;
    final names = {...available, ...enabled}.toList()..sort();
    return [
      for (final name in names)
        NginxSite(
          name: name,
          enabled: enabled.contains(name),
          availablePath: '/etc/nginx/sites-available/$name',
          configType: _inferNginxSiteType(name),
          serverNames: siteDomains[name] ?? const [],
          certificate:
              _matchCertificate(siteName: name, serverNames: siteDomains[name] ?? const [], certificates: certificates),
        ),
    ];
  }

  NginxCertificateInfo? _parseCertificateLine(String line) {
    final parts = line.split('|');
    if (parts.length < 4 || !_isSafeSiteName(parts[0])) {
      return null;
    }
    final epoch = int.tryParse(parts[1]);
    final expiresAt = epoch == null || epoch <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    final domains = _parseDomainList(parts.length > 5 ? parts[5] : (parts.length > 4 ? parts[4] : ''));
    return NginxCertificateInfo(
      certName: parts[0],
      expiresAt: expiresAt,
      issuer: parts[2].isEmpty ? null : parts[2],
      fullchainPath: parts[3],
      privateKeyPath: parts.length > 5 && parts[4].isNotEmpty ? parts[4] : null,
      domains: domains,
      status: _certificateStatus(expiresAt),
    );
  }

  List<String> _parseDomainList(String value) {
    return value
        .split(RegExp(r'\s+'))
        .map((domain) => domain.trim())
        .where((domain) =>
            domain.isNotEmpty && domain != '_' && _isSafeSiteName(domain.replaceFirst(RegExp(r'^\*\.'), 'wildcard.')))
        .toSet()
        .toList();
  }

  List<String> _parseCertificateRequestDomains(String value) {
    return value
        .split(RegExp(r'[\s,]+'))
        .map((domain) => domain.trim())
        .where((domain) => domain.isNotEmpty && _isSafeSiteName(domain.replaceFirst(RegExp(r'^\*\.'), 'wildcard.')))
        .toSet()
        .toList();
  }

  NginxCertificateInfo? _matchCertificate({
    required String siteName,
    required List<String> serverNames,
    required List<NginxCertificateInfo> certificates,
  }) {
    final candidates = {
      siteName,
      ...serverNames,
    };
    for (final certificate in certificates) {
      final certificateNames = {
        certificate.certName,
        ...certificate.domains,
      };
      if (candidates.any(certificateNames.contains)) {
        return certificate;
      }
    }
    return null;
  }

  CertificateStatus _certificateStatus(DateTime? expiresAt) {
    if (expiresAt == null) {
      return CertificateStatus.unknown;
    }
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) {
      return CertificateStatus.expired;
    }
    if (expiresAt.difference(now).inDays <= 30) {
      return CertificateStatus.expiringSoon;
    }
    return CertificateStatus.valid;
  }

  NginxSiteType _inferNginxSiteType(String name) {
    if (name.contains('proxy') || name.contains('api')) {
      return NginxSiteType.reverseProxy;
    }
    return NginxSiteType.custom;
  }

  String _nginxSiteTargetPrefix(String site) {
    final enabledPath = '/etc/nginx/sites-enabled/$site';
    final availablePath = '/etc/nginx/sites-available/$site';
    return 'enabled=${shellQuote(enabledPath)}; '
        'available=${shellQuote(availablePath)}; '
        'if [ -e "\$enabled" ] || [ -L "\$enabled" ]; then '
        '  resolved=\$(readlink -f "\$enabled" 2>/dev/null || true); '
        '  if [ -n "\$resolved" ]; then target="\$resolved"; else target="\$enabled"; fi; '
        'else '
        '  target="\$available"; '
        'fi;';
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

String _overviewCommandFor(List<String> services) {
  final quotedServices = services.map(shellQuote).join(' ');
  return '''
$_overviewBaseCommand
for svc in $quotedServices; do
  status=\$(systemctl is-active "\$svc" 2>/dev/null || true)
  enabled=\$(systemctl is-enabled "\$svc" 2>/dev/null || true)
  printf "service=%s;status=%s;enabled=%s\\n" "\$svc" "\${status:-unknown}" "\${enabled:-unknown}"
done
''';
}

const _overviewBaseCommand = r'''
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

const _builtInWebsiteTemplates = [
  NginxTemplateDefinition(
    id: 'static_site',
    name: '静态网站',
    type: '静态站点',
    description: '标准 root + try_files 配置',
    builtIn: true,
    content: '''
server {
    listen 80;
    server_name {{domain}};
    root {{root_path}};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    access_log /var/log/nginx/{{domain}}_access.log;
    error_log /var/log/nginx/{{domain}}_error.log;
}
''',
  ),
  NginxTemplateDefinition(
    id: 'reverse_proxy',
    name: '反向代理',
    type: '反向代理',
    description: '转发到本机上游服务',
    builtIn: true,
    content: '''
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
''',
  ),
];
