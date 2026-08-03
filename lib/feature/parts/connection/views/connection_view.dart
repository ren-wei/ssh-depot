import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../assets/connection_asset.dart';
import '../../../classes/server_profile.dart';
import '../../../components/app_scope.dart';
import '../../../components/depot_scrollbar.dart';
import '../../../cubits/app_controller.dart';
import '../../../utils/shell_quote.dart';

const _bg = Color(0xff04130d);
const _panel = Color(0xff0b2418);
const _panelAlt = Color(0xff103520);
const _line = Color(0xff1d5940);
const _lineDim = Color(0xff16432f);
const _text = Color(0xffeef8f2);
const _muted = Color(0xff9db4a8);
const _accent = Color(0xff3fe09a);

class ConnectionView extends StatelessWidget {
  const ConnectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: ConnectionBackgroundImage(),
                fit: BoxFit.cover,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x66000000),
            ),
          ),
          SafeArea(
            child: Center(
              child: _ConnectionScroll(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionScroll extends StatefulWidget {
  const _ConnectionScroll();

  @override
  State<_ConnectionScroll> createState() => _ConnectionScrollState();
}

class _ConnectionScrollState extends State<_ConnectionScroll> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DepotScrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(28),
        child: const _ConnectionContent(),
      ),
    );
  }
}

class _ConnectionContent extends StatefulWidget {
  const _ConnectionContent();

  @override
  State<_ConnectionContent> createState() => _ConnectionContentState();
}

class _ConnectionContentState extends State<_ConnectionContent> {
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _userController = TextEditingController(text: 'root');
  String? _hostError;
  String? _userError;
  bool? _lastTestSucceeded;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final compact = MediaQuery.sizeOf(context).width < 860;

    return Container(
      width: compact ? double.infinity : 880,
      constraints: const BoxConstraints(maxWidth: 920),
      padding: EdgeInsets.all(compact ? 22 : 38),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '连接服务器',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _text,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '先从已保存的服务器里选择，或新建配置后连接。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _muted),
          ),
          const SizedBox(height: 24),
          Flex(
            direction: compact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: compact ? double.infinity : 284,
                child: _SavedServersPanel(
                  servers: controller.servers,
                  disabled: controller.isRunning,
                  onSelect: _fillServer,
                  onCreate: _clearForm,
                  onConnect: (server) => _quickLogin(controller, server),
                  onCopyAuthorizationCommand: _copyAuthorizationCommand,
                ),
              ),
              SizedBox(width: compact ? 0 : 20, height: compact ? 20 : 0),
              if (compact)
                _ConnectionPanel(
                  nameController: _nameController,
                  hostController: _hostController,
                  userController: _userController,
                  isRunning: controller.isRunning,
                  testSucceeded: _lastTestSucceeded,
                  hostError: _hostError,
                  userError: _userError,
                  terminalText: controller.terminalLines.join(),
                  onSubmitted: () => _login(controller),
                  onTest: () => _testConnection(controller),
                  onConnect: () => _login(controller),
                  onSave: () => _save(controller),
                  onCopyTroubleshootCommand: _copyTroubleshootCommand,
                )
              else
                Expanded(
                  child: _ConnectionPanel(
                    nameController: _nameController,
                    hostController: _hostController,
                    userController: _userController,
                    isRunning: controller.isRunning,
                    testSucceeded: _lastTestSucceeded,
                    hostError: _hostError,
                    userError: _userError,
                    terminalText: controller.terminalLines.join(),
                    onSubmitted: () => _login(controller),
                    onTest: () => _testConnection(controller),
                    onConnect: () => _login(controller),
                    onSave: () => _save(controller),
                    onCopyTroubleshootCommand: _copyTroubleshootCommand,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection(AppController controller) async {
    final host = _validHostOrNull();
    final user = _validUserOrNull();
    if (host == null || user == null) {
      return;
    }
    setState(() => _lastTestSucceeded = null);
    final succeeded = await controller.testConnection(host, user: user);
    if (!mounted) {
      return;
    }
    setState(() => _lastTestSucceeded = succeeded);
  }

  Future<void> _login(AppController controller) async {
    await _connect(controller);
    if (!mounted || !controller.isConnected) {
      return;
    }
    context.go('/overview');
  }

  Future<void> _connect(AppController controller) async {
    final host = _validHostOrNull();
    final user = _validUserOrNull();
    if (host == null || user == null) {
      return;
    }
    await controller.connect(host, user: user);
  }

  String? _validHostOrNull() {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      setState(() {
        _hostError = '请输入主机 IP 或 ~/.ssh/config Host 别名';
        _lastTestSucceeded = false;
      });
      return null;
    }
    setState(() => _hostError = null);
    return host;
  }

  String? _validUserOrNull() {
    final user = _userController.text.trim();
    if (user.isEmpty) {
      setState(() {
        _userError = '请输入用户名';
        _lastTestSucceeded = false;
      });
      return null;
    }
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_.-]*[$]?$').hasMatch(user)) {
      setState(() {
        _userError = '请输入有效用户名';
        _lastTestSucceeded = false;
      });
      return null;
    }
    setState(() => _userError = null);
    return user;
  }

  Future<void> _quickLogin(
    AppController controller,
    ServerProfile server,
  ) async {
    _fillServer(server);
    await _login(controller);
  }

  Future<void> _save(AppController controller) async {
    final host = _hostController.text.trim();
    final user = _validUserOrNull();
    if (host.isEmpty) {
      setState(() => _hostError = '请输入主机 IP 或 ~/.ssh/config Host 别名');
      return;
    }
    if (user == null) {
      return;
    }
    setState(() => _hostError = null);
    await controller.saveServer(
      ServerProfile(
        name: _nameController.text.trim().isEmpty ? host : _nameController.text.trim(),
        host: host,
        user: user,
      ),
    );
  }

  Future<void> _copyAuthorizationCommand() async {
    final user = _validUserOrNull();
    if (user == null) {
      return;
    }
    final publicKey = await _readLocalPublicKey();
    if (!mounted) {
      return;
    }
    if (publicKey == null) {
      await Clipboard.setData(const ClipboardData(text: 'ssh-keygen -t ed25519'));
      _showConnectionSnackBar(
        '未找到本机 SSH 公钥，已复制生成公钥命令：ssh-keygen -t ed25519',
      );
      return;
    }

    final command = _authorizationCommandFor(publicKey.key);
    await Clipboard.setData(ClipboardData(text: command));
    if (!mounted) {
      return;
    }
    _showConnectionSnackBar(
      '已复制 ${publicKey.path} 的授权命令，请在目标服务器 $user 用户下执行。',
    );
  }

  Future<void> _copyTroubleshootCommand() async {
    final user = _validUserOrNull();
    if (user == null) {
      return;
    }
    final publicKey = await _readLocalPublicKey();
    if (!mounted) {
      return;
    }
    final command = _troubleshootCommandFor(publicKey?.key);
    await Clipboard.setData(ClipboardData(text: command));
    if (!mounted) {
      return;
    }
    _showConnectionSnackBar(
      publicKey == null ? '已复制排查命令；未找到本机公钥，命令会跳过 authorized_keys 内容匹配。' : '已复制排查命令，请在目标服务器 $user 用户下执行并查看输出。',
    );
  }

  Future<_LocalPublicKey?> _readLocalPublicKey() async {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      return null;
    }

    final candidates = [
      '$home/.ssh/id_ed25519.pub',
      '$home/.ssh/id_rsa.pub',
      '$home/.ssh/id_ecdsa.pub',
      '$home/.ssh/id_dsa.pub',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }
      final key = (await file.readAsString()).trim();
      if (_isPublicKey(key)) {
        return _LocalPublicKey(path: path, key: key);
      }
    }
    return null;
  }

  bool _isPublicKey(String value) {
    return value.startsWith('ssh-ed25519 ') ||
        value.startsWith('ssh-rsa ') ||
        value.startsWith('ecdsa-sha2-') ||
        value.startsWith('sk-ssh-ed25519@openssh.com ') ||
        value.startsWith('sk-ecdsa-sha2-nistp256@openssh.com ');
  }

  String _authorizationCommandFor(String publicKey) {
    final quotedKey = shellQuote(publicKey);
    return 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && '
        'touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && '
        'grep -qxF $quotedKey ~/.ssh/authorized_keys || '
        'printf "%s\\n" $quotedKey >> ~/.ssh/authorized_keys';
  }

  String _troubleshootCommandFor(String? publicKey) {
    final quotedKey = shellQuote(publicKey ?? '');
    return '''
set -u
echo "== ssh-depot SSH 连接排查 =="
echo "[提示] 请在应用里填写的同一个 SSH 用户下执行本命令。"
echo "[提示] 本命令排查目标机账户、公钥和 sshd 配置；网络、端口、防火墙仍需在本机用 ssh -vvv 排查。"
echo

problems=0
current_user=\$(id -un 2>/dev/null || whoami)
home_dir="\${HOME:-}"
if [ -z "\$home_dir" ] && command -v getent >/dev/null 2>&1; then
  home_dir=\$(getent passwd "\$current_user" | cut -d: -f6)
fi
ssh_dir="\$home_dir/.ssh"
authorized_keys="\$ssh_dir/authorized_keys"
expected_key=$quotedKey

echo "[用户] \$current_user"
echo "[HOME] \$home_dir"
echo

if [ -z "\$home_dir" ]; then
  echo "原因: 无法识别当前用户 HOME 目录。"
  problems=\$((problems + 1))
elif [ ! -d "\$ssh_dir" ]; then
  echo "原因: \$ssh_dir 不存在。需要先创建并授权本机公钥。"
  problems=\$((problems + 1))
else
  ssh_perm=\$(stat -c "%a" "\$ssh_dir" 2>/dev/null || echo "?")
  ssh_owner=\$(stat -c "%U" "\$ssh_dir" 2>/dev/null || echo "?")
  echo "[检查] \$ssh_dir 权限=\$ssh_perm 所有者=\$ssh_owner"
  if [ "\$ssh_perm" != "700" ]; then
    echo "原因: \$ssh_dir 权限不是 700，sshd 可能拒绝读取。修复: chmod 700 ~/.ssh"
    problems=\$((problems + 1))
  fi
  if [ "\$ssh_owner" != "\$current_user" ]; then
    echo "原因: \$ssh_dir 所有者不是当前用户。修复: chown \$current_user:\$current_user ~/.ssh"
    problems=\$((problems + 1))
  fi
fi

if [ ! -f "\$authorized_keys" ]; then
  echo "原因: \$authorized_keys 不存在。需要把本机公钥追加进去。"
  problems=\$((problems + 1))
else
  key_perm=\$(stat -c "%a" "\$authorized_keys" 2>/dev/null || echo "?")
  key_owner=\$(stat -c "%U" "\$authorized_keys" 2>/dev/null || echo "?")
  echo "[检查] \$authorized_keys 权限=\$key_perm 所有者=\$key_owner"
  if [ "\$key_perm" != "600" ]; then
    echo "原因: authorized_keys 权限不是 600，sshd 可能拒绝读取。修复: chmod 600 ~/.ssh/authorized_keys"
    problems=\$((problems + 1))
  fi
  if [ "\$key_owner" != "\$current_user" ]; then
    echo "原因: authorized_keys 所有者不是当前用户。修复: chown \$current_user:\$current_user ~/.ssh/authorized_keys"
    problems=\$((problems + 1))
  fi
  if [ -n "\$expected_key" ]; then
    if grep -qxF "\$expected_key" "\$authorized_keys"; then
      echo "[检查] authorized_keys 已包含本机公钥"
    else
      echo "原因: authorized_keys 未包含本机公钥。请重新执行“复制授权命令”。"
      problems=\$((problems + 1))
    fi
  else
    echo "[跳过] 未带入本机公钥，无法检查 authorized_keys 是否包含正确公钥。"
  fi
fi

if command -v sshd >/dev/null 2>&1; then
  effective=\$(sshd -T -C user="\$current_user",host=localhost,addr=127.0.0.1 2>/dev/null || true)
  if [ -n "\$effective" ]; then
    pubkey_auth=\$(printf "%s\\n" "\$effective" | awk '/^pubkeyauthentication / {print \$2; exit}')
    password_auth=\$(printf "%s\\n" "\$effective" | awk '/^passwordauthentication / {print \$2; exit}')
    authorized_file=\$(printf "%s\\n" "\$effective" | awk '/^authorizedkeysfile / {for (i=2; i<=NF; i++) printf "%s%s", (i==2 ? "" : " "), \$i; print ""; exit}')
    echo "[检查] PubkeyAuthentication=\${pubkey_auth:-unknown}"
    echo "[检查] PasswordAuthentication=\${password_auth:-unknown}"
    echo "[检查] AuthorizedKeysFile=\${authorized_file:-unknown}"
    if [ "\${pubkey_auth:-yes}" = "no" ]; then
      echo "原因: sshd 禁用了公钥认证。需要在 sshd 配置中启用 PubkeyAuthentication。"
      problems=\$((problems + 1))
    fi
  else
    echo "[提示] sshd -T 无法读取有效配置，改用配置文件关键词检查。"
  fi
else
  echo "[提示] 未找到 sshd 命令，跳过 sshd 有效配置检查。"
fi

config_hits=\$(grep -hE "^[[:space:]]*(PubkeyAuthentication|PasswordAuthentication|PermitRootLogin|AuthorizedKeysFile)[[:space:]]+" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true)
if [ -n "\$config_hits" ]; then
  echo
  echo "[sshd 配置片段]"
  printf "%s\\n" "\$config_hits"
fi

echo
if [ "\$problems" -eq 0 ]; then
  echo "未在目标机账户、公钥和 sshd 基础配置中发现明显问题。"
  echo "下一步请在本机执行: ssh -vvv \$current_user@<服务器地址> 'echo __ssh-depot_ok__'"
else
  echo "发现 \$problems 个可能原因，请按上方原因修复后重新测试连接。"
fi
'''
        .trim();
  }

  void _showConnectionSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: _text.withValues(alpha: 0.92),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _panel,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _lineDim),
        ),
      ),
    );
  }

  void _fillServer(ServerProfile server) {
    setState(() {
      _nameController.text = server.name.isEmpty ? server.host : server.name;
      _hostController.text = server.host;
      _userController.text = server.user.isEmpty ? 'root' : server.user;
      _hostError = null;
      _userError = null;
      _lastTestSucceeded = null;
    });
  }

  void _clearForm() {
    setState(() {
      _nameController.clear();
      _hostController.clear();
      _userController.text = 'root';
      _hostError = null;
      _userError = null;
      _lastTestSucceeded = null;
    });
  }
}

class _LocalPublicKey {
  const _LocalPublicKey({required this.path, required this.key});

  final String path;
  final String key;
}

class _SavedServersPanel extends StatelessWidget {
  const _SavedServersPanel({
    required this.servers,
    required this.disabled,
    required this.onSelect,
    required this.onCreate,
    required this.onConnect,
    required this.onCopyAuthorizationCommand,
  });

  final List<ServerProfile> servers;
  final bool disabled;
  final ValueChanged<ServerProfile> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<ServerProfile> onConnect;
  final VoidCallback onCopyAuthorizationCommand;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('已保存的服务器', style: _titleStyle(context)),
          const SizedBox(height: 4),
          Text('点击即可填入表单', style: _captionStyle(context)),
          const SizedBox(height: 18),
          if (servers.isEmpty)
            const _EmptySavedServers()
          else
            for (final server in servers.take(5)) ...[
              _ServerTile(
                server: server,
                disabled: disabled,
                isDefault: servers.first == server,
                onSelect: () => onSelect(server),
                onConnect: () => onConnect(server),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 58),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: disabled ? null : onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增服务器'),
              style: _outlinedButtonStyle(),
            ),
          ),
          const SizedBox(height: 14),
          _AuthorizationHelpBox(
            isRunning: disabled,
            onCopyAuthorizationCommand: onCopyAuthorizationCommand,
          ),
        ],
      ),
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({
    required this.nameController,
    required this.hostController,
    required this.userController,
    required this.isRunning,
    required this.testSucceeded,
    required this.hostError,
    required this.userError,
    required this.terminalText,
    required this.onSubmitted,
    required this.onTest,
    required this.onConnect,
    required this.onSave,
    required this.onCopyTroubleshootCommand,
  });

  final TextEditingController nameController;
  final TextEditingController hostController;
  final TextEditingController userController;
  final bool isRunning;
  final bool? testSucceeded;
  final String? hostError;
  final String? userError;
  final String terminalText;
  final VoidCallback onSubmitted;
  final VoidCallback onTest;
  final VoidCallback onConnect;
  final VoidCallback onSave;
  final VoidCallback onCopyTroubleshootCommand;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('连接信息', style: _titleStyle(context)),
          const SizedBox(height: 4),
          Text('仅支持密钥认证，用户名默认 root，可按服务器配置修改', style: _captionStyle(context)),
          const SizedBox(height: 22),
          const _FieldLabel('服务器名称'),
          const SizedBox(height: 7),
          _DarkTextField(
            controller: nameController,
            hintText: '请输入服务器名称',
            enabled: !isRunning,
          ),
          const SizedBox(height: 14),
          const _FieldLabel('主机 / 别名'),
          const SizedBox(height: 7),
          _DarkTextField(
            controller: hostController,
            hintText: '1.2.3.4',
            enabled: !isRunning,
            errorText: hostError,
            onSubmitted: (_) => onSubmitted(),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('用户名'),
          const SizedBox(height: 7),
          _DarkTextField(
            controller: userController,
            hintText: 'root',
            enabled: !isRunning,
            errorText: userError,
            onSubmitted: (_) => onSubmitted(),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: isRunning ? null : onTest,
                  icon: _PulseDot(
                    color: isRunning
                        ? Color(0xffffcf63)
                        : switch (testSucceeded) {
                            true => _accent,
                            false => Color(0xffff6d92),
                            null => _muted,
                          },
                  ),
                  label: Text(isRunning ? '连接中' : '测试连接'),
                  style: _outlinedButtonStyle(),
                ),
              ),
              SizedBox(
                height: 44,
                child: testSucceeded == false
                    ? FilledButton.icon(
                        onPressed: isRunning ? null : onCopyTroubleshootCommand,
                        icon: const Icon(Icons.manage_search, size: 18),
                        label: const Text('复制排查命令'),
                        style: _filledConnectButtonStyle(),
                      )
                    : FilledButton(
                        onPressed: isRunning ? null : onConnect,
                        style: _filledConnectButtonStyle(),
                        child: Text(isRunning ? '连接中' : '开始连接'),
                      ),
              ),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: isRunning ? null : onSave,
                  style: _outlinedButtonStyle(),
                  child: const Text('保存配置'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TerminalOutputBox(text: terminalText),
        ],
      ),
    );
  }
}

class _AuthorizationHelpBox extends StatelessWidget {
  const _AuthorizationHelpBox({
    required this.isRunning,
    required this.onCopyAuthorizationCommand,
  });

  final bool isRunning;
  final VoidCallback onCopyAuthorizationCommand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xff071a11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lineDim),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final copyButton = OutlinedButton.icon(
            onPressed: isRunning ? null : onCopyAuthorizationCommand,
            icon: const Icon(Icons.copy, size: 16),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('复制授权命令'),
            ),
            style: _outlinedButtonStyle().copyWith(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          );
          final description = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.key_outlined, color: _accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '首次连接需要先授权本机公钥',
                      style: _titleStyle(context).copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '复制命令后，在目标服务器当前填写的 SSH 用户下执行；完成后回到这里点击“测试连接”。',
                      style: _captionStyle(context).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                description,
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: copyButton,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: description),
              const SizedBox(width: 12),
              copyButton,
            ],
          );
        },
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.server,
    required this.disabled,
    required this.isDefault,
    required this.onSelect,
    required this.onConnect,
  });

  final ServerProfile server;
  final bool disabled;
  final bool isDefault;
  final VoidCallback onSelect;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final name = server.name.isEmpty ? server.host : server.name;
    return Material(
      color: isDefault ? _panelAlt : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: disabled ? null : onSelect,
        onDoubleTap: disabled ? null : onConnect,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isDefault ? _line : _lineDim),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isDefault ? _accent : _muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      server.target,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _captionStyle(context),
                    ),
                    if (server.remark != null && server.remark!.trim().isNotEmpty)
                      Text(
                        server.remark!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _captionStyle(context),
                      ),
                  ],
                ),
              ),
              if (isDefault)
                SizedBox(
                  height: 28,
                  child: FilledButton(
                    onPressed: disabled ? null : onConnect,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xff08321f),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('默认'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xff0a2016),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _lineDim),
      ),
      child: child,
    );
  }
}

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    this.controller,
    this.hintText,
    this.errorText,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(color: _text, fontWeight: FontWeight.w700),
      cursorColor: _accent,
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        hintStyle: TextStyle(color: _muted.withValues(alpha: 0.72)),
        errorStyle: const TextStyle(color: Color(0xffff8a7a), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        filled: true,
        fillColor: const Color(0xff06170f),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _lineDim.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _lineDim),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xffff8a7a)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _accent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xffff8a7a)),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _captionStyle(context).copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _TerminalOutputBox extends StatefulWidget {
  const _TerminalOutputBox({required this.text});

  final String text;

  @override
  State<_TerminalOutputBox> createState() => _TerminalOutputBoxState();
}

class _TerminalOutputBoxState extends State<_TerminalOutputBox> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant _TerminalOutputBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final output = widget.text.trim().isEmpty ? '暂无输出' : widget.text.trimRight();
    return Container(
      width: double.infinity,
      height: 148,
      decoration: BoxDecoration(
        color: const Color(0xff020b07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lineDim),
      ),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _lineDim)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: _muted, size: 16),
                const SizedBox(width: 8),
                Text(
                  '终端',
                  style: _captionStyle(
                    context,
                  ).copyWith(color: _text, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.text.trim().isEmpty ? null : () => _copyForAi(context),
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy for ai'),
                  style: TextButton.styleFrom(
                    foregroundColor: _text,
                    disabledForegroundColor: _muted.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DepotScrollbar(
              controller: _scrollController,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 22,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SelectableText(
                          output,
                          style: TextStyle(
                            color: widget.text.trim().isEmpty ? _muted : const Color(0xffd6eadf),
                            fontFamily: 'monospace',
                            fontFamilyFallback: const [
                              'Noto Sans Mono CJK SC',
                              'Noto Sans CJK SC',
                              'Noto Sans CJK',
                              'WenQuanYi Micro Hei',
                            ],
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyForAi(BuildContext context) async {
    final block = _lastCommandBlock(widget.text);
    final content = '''
请分析下面这次 ssh-depot 终端命令和输出，定位问题原因并给出修复建议：

```text
$block
```
''';
    await Clipboard.setData(ClipboardData(text: content.trim()));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制最后一条命令和输出')),
    );
  }

  String _lastCommandBlock(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) {
      return '暂无输出';
    }
    final markerIndex = trimmed.lastIndexOf('\n\$ ');
    if (markerIndex >= 0) {
      return trimmed.substring(markerIndex + 1).trimRight();
    }
    if (trimmed.startsWith(r'$ ')) {
      return trimmed;
    }
    return trimmed;
  }
}

class _EmptySavedServers extends StatelessWidget {
  const _EmptySavedServers();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xff071a11),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _lineDim),
      ),
      child: Column(
        children: [
          Icon(Icons.dns_outlined, color: _muted.withValues(alpha: 0.75)),
          const SizedBox(height: 10),
          Text('暂无已保存服务器', style: _titleStyle(context)),
          const SizedBox(height: 4),
          Text('填写右侧表单后保存配置', style: _captionStyle(context)),
        ],
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

TextStyle _titleStyle(BuildContext context) {
  return Theme.of(
    context,
  ).textTheme.titleSmall!.copyWith(color: _text, fontWeight: FontWeight.w800);
}

TextStyle _captionStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall!.copyWith(color: _muted);
}

ButtonStyle _outlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: _text,
    disabledForegroundColor: _muted.withValues(alpha: 0.48),
    side: const BorderSide(color: _line),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

ButtonStyle _filledConnectButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _accent,
    foregroundColor: const Color(0xff042014),
    disabledBackgroundColor: _accent.withValues(alpha: 0.38),
    padding: const EdgeInsets.symmetric(horizontal: 28),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}
