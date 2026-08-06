import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ssh_depot/feature/assets/connection_asset.dart';
import 'package:ssh_depot/feature/classes/server_profile.dart';
import 'package:ssh_depot/feature/components/depot_scrollbar.dart';
import 'package:ssh_depot/feature/components/depot_snack_bar.dart';
import 'package:ssh_depot/feature/cubits/app_connection_cubit.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/cubits/servers_cubit.dart';
import 'package:ssh_depot/feature/cubits/terminal_cubit.dart';
import 'package:ssh_depot/feature/parts/connection/commands/ssh_authorization_command.dart';
import 'package:ssh_depot/feature/parts/connection/commands/ssh_troubleshoot_command.dart';
import 'package:ssh_depot/feature/parts/connection/services/local_ssh_key_reader.dart';

part 'connection_view_widgets.dart';
part 'connection_view_saved_servers.dart';
part 'connection_view_form_panel.dart';
part 'connection_view_styles.dart';
part 'connection_view_terminal.dart';

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
                image: ConnectionAsset.background,
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
    final runner = _maybeRead<CommandRunnerCubit>(context);
    final connection = context.watch<AppConnectionCubit>();
    final servers = context.watch<ServersCubit>();
    final terminal = context.watch<TerminalCubit>();
    final compact = MediaQuery.sizeOf(context).width < 860;
    final isRunning = runner?.isRunning ?? false;
    final isTesting = connection.isTesting;
    final terminalText = terminal.output;

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
                  servers: servers.servers,
                  disabled: isRunning || isTesting,
                  onSelect: _fillServer,
                  onCreate: _clearForm,
                  onConnect: (server) => _quickLogin(connection, server),
                  onCopyAuthorizationCommand: _copyAuthorizationCommand,
                ),
              ),
              SizedBox(width: compact ? 0 : 20, height: compact ? 20 : 0),
              if (compact)
                _ConnectionPanel(
                  nameController: _nameController,
                  hostController: _hostController,
                  userController: _userController,
                  isRunning: isRunning || isTesting,
                  testSucceeded: _lastTestSucceeded,
                  hostError: _hostError,
                  userError: _userError,
                  terminalText: terminalText,
                  onSubmitted: () => _login(connection),
                  onTest: () => _testConnection(connection),
                  onConnect: () => _login(connection),
                  onSave: () => _save(servers, runner, connection),
                  onCopyTroubleshootCommand: _copyTroubleshootCommand,
                )
              else
                Expanded(
                  child: _ConnectionPanel(
                    nameController: _nameController,
                    hostController: _hostController,
                    userController: _userController,
                    isRunning: isRunning || isTesting,
                    testSucceeded: _lastTestSucceeded,
                    hostError: _hostError,
                    userError: _userError,
                    terminalText: terminalText,
                    onSubmitted: () => _login(connection),
                    onTest: () => _testConnection(connection),
                    onConnect: () => _login(connection),
                    onSave: () => _save(servers, runner, connection),
                    onCopyTroubleshootCommand: _copyTroubleshootCommand,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection(AppConnectionCubit connection) async {
    final host = _validHostOrNull();
    final user = _validUserOrNull();
    if (host == null || user == null) {
      return;
    }
    setState(() => _lastTestSucceeded = null);
    final succeeded = await connection.testConnection(host, user: user);
    if (!mounted) {
      return;
    }
    setState(() => _lastTestSucceeded = succeeded);
  }

  Future<void> _login(AppConnectionCubit connection) async {
    await _connect(connection);
    if (!mounted || !connection.hasTarget) {
      return;
    }
    context.go('/overview');
  }

  Future<void> _connect(AppConnectionCubit connection) async {
    final host = _validHostOrNull();
    final user = _validUserOrNull();
    if (host == null || user == null) {
      return;
    }
    connection.requestConnect(host, user: user);
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
    AppConnectionCubit connection,
    ServerProfile server,
  ) async {
    _fillServer(server);
    await _login(connection);
  }

  Future<void> _save(ServersCubit servers, CommandRunnerCubit? runner, AppConnectionCubit connection) async {
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
    final server = ServerProfile(
      name: _nameController.text.trim().isEmpty ? host : _nameController.text.trim(),
      host: host,
      user: user,
    );
    try {
      await servers.saveServer(server);
      if (runner == null) {
        connection.setStatus('✓ 已保存服务器 ${server.target}');
      } else {
        runner.setStatus('✓ 已保存服务器 ${server.target}');
      }
    } catch (error) {
      if (runner == null) {
        connection.setStatus('✗ 保存服务器失败: $error');
      } else {
        runner.setStatus('✗ 保存服务器失败: $error');
      }
    }
  }

  Future<void> _copyAuthorizationCommand() async {
    final user = _validUserOrNull();
    if (user == null) {
      return;
    }
    final publicKey = await readLocalPublicKey();
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

    final command = authorizationCommandFor(publicKey.key);
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
    final publicKey = await readLocalPublicKey();
    if (!mounted) {
      return;
    }
    final command = troubleshootCommandFor(publicKey?.key);
    await Clipboard.setData(ClipboardData(text: command));
    if (!mounted) {
      return;
    }
    _showConnectionSnackBar(
      publicKey == null ? '已复制排查命令；未找到本机公钥，命令会跳过 authorized_keys 内容匹配。' : '已复制排查命令，请在目标服务器 $user 用户下执行并查看输出。',
    );
  }

  void _showConnectionSnackBar(String message) {
    showDepotSnackBar(context, message);
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
