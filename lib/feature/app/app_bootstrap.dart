import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:ssh_depot/feature/cubits/app_connection_cubit.dart';
import 'package:ssh_depot/feature/cubits/servers_cubit.dart';
import 'package:ssh_depot/feature/cubits/terminal_cubit.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({required this.child, super.key});

  final Widget child;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final ServersCubit _serversCubit;
  late final TerminalCubit _terminalCubit;
  late final AppConnectionCubit _connectionCubit;

  @override
  void initState() {
    super.initState();
    _serversCubit = ServersCubit();
    _terminalCubit = TerminalCubit();
    _connectionCubit = AppConnectionCubit(terminalCubit: _terminalCubit);
    _serversCubit.load();
  }

  @override
  void dispose() {
    _serversCubit.dispose();
    _terminalCubit.dispose();
    _connectionCubit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ListenableProvider<ServersCubit>.value(value: _serversCubit),
        ListenableProvider<TerminalCubit>.value(value: _terminalCubit),
        ListenableProvider<AppConnectionCubit>.value(value: _connectionCubit),
      ],
      child: widget.child,
    );
  }
}
