import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssh_depot/feature/cubits/app_connection_cubit.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/cubits/operation_history_cubit.dart';
import 'package:ssh_depot/feature/cubits/servers_cubit.dart';
import 'package:ssh_depot/feature/cubits/terminal_cubit.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

class ConnectedSession extends StatefulWidget {
  const ConnectedSession({
    required this.target,
    required this.child,
    super.key,
  });

  final SshTarget target;
  final Widget child;

  @override
  State<ConnectedSession> createState() => _ConnectedSessionState();
}

class _ConnectedSessionState extends State<ConnectedSession> {
  late final TerminalCubit _terminalCubit;
  late final OperationHistoryCubit _operationHistoryCubit;
  late final CommandRunnerCubit _commandRunnerCubit;
  bool _connecting = true;

  @override
  void initState() {
    super.initState();
    _terminalCubit = TerminalCubit();
    _operationHistoryCubit = OperationHistoryCubit();
    _commandRunnerCubit = CommandRunnerCubit(
      terminalCubit: _terminalCubit,
      historyCubit: _operationHistoryCubit,
      currentTarget: () => widget.target,
    );
    _openSession();
  }

  Future<void> _openSession() async {
    final appConnection = context.read<AppConnectionCubit>();
    final serversCubit = context.read<ServersCubit>();
    final exitCode = await _commandRunnerCubit.openMasterAndVerify(widget.target);
    if (!mounted) {
      return;
    }
    if (exitCode != 0) {
      appConnection.failConnection('✗ 建立 SSH 连接失败');
      return;
    }
    await serversCubit.saveServer(
      serversCubit.profileForSuccessfulConnect(widget.target.host, widget.target.user),
    );
    appConnection.markConnected();
    if (mounted) {
      setState(() {
        _connecting = false;
      });
    }
  }

  @override
  void dispose() {
    _commandRunnerCubit.closeMaster(widget.target, appendOutput: false);
    _terminalCubit.dispose();
    _operationHistoryCubit.dispose();
    _commandRunnerCubit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ListenableProvider<TerminalCubit>.value(value: _terminalCubit),
        ListenableProvider<OperationHistoryCubit>.value(value: _operationHistoryCubit),
        ListenableProvider<CommandRunnerCubit>.value(value: _commandRunnerCubit),
        Provider<SshTarget>.value(value: widget.target),
      ],
      child: _connecting ? const _ConnectingView() : widget.child,
    );
  }
}

class _ConnectingView extends StatelessWidget {
  const _ConnectingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
