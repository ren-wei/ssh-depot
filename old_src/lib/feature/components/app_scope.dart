import 'package:flutter/widgets.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/cubits/connection_cubit.dart';
import 'package:ssh_depot/feature/cubits/operation_history_cubit.dart';
import 'package:ssh_depot/feature/cubits/servers_cubit.dart';
import 'package:ssh_depot/feature/cubits/terminal_cubit.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';
import 'package:ssh_depot/feature/parts/nginx/cubits/nginx_cubit.dart';
import 'package:ssh_depot/feature/parts/overview/cubits/overview_cubit.dart';
import 'package:ssh_depot/feature/parts/packages/cubits/packages_cubit.dart';
import 'package:ssh_depot/feature/parts/services/cubits/services_cubit.dart';
import 'package:ssh_depot/feature/parts/ssl/cubits/ssl_cubit.dart';

class AppScope extends StatefulWidget {
  const AppScope({required this.child, super.key});

  final Widget child;

  static TerminalCubit terminal(BuildContext context) => _of(context).terminalCubit;
  static OperationHistoryCubit operationHistory(BuildContext context) => _of(context).operationHistoryCubit;
  static ServersCubit servers(BuildContext context) => _of(context).serversCubit;
  static CommandRunnerCubit commandRunner(BuildContext context) => _of(context).commandRunnerCubit;
  static ConnectionCubit connection(BuildContext context) => _of(context).connectionCubit;
  static PackagesCubit packages(BuildContext context) => _of(context).packagesCubit;
  static ServicesCubit services(BuildContext context) => _of(context).servicesCubit;
  static OverviewCubit overview(BuildContext context) => _of(context).overviewCubit;
  static NginxCubit nginx(BuildContext context) => _of(context).nginxCubit;
  static SslCubit ssl(BuildContext context) => _of(context).sslCubit;

  static _AppScopeInherited _of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AppScopeInherited>();
    assert(scope != null, 'AppScope not found in widget tree.');
    return scope!;
  }

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> {
  late final TerminalCubit _terminalCubit;
  late final OperationHistoryCubit _operationHistoryCubit;
  late final ServersCubit _serversCubit;
  late final CommandRunnerCubit _commandRunnerCubit;
  late final ConnectionCubit _connectionCubit;
  late final PackagesCubit _packagesCubit;
  late final ServicesCubit _servicesCubit;
  late final OverviewCubit _overviewCubit;
  late final NginxCubit _nginxCubit;
  late final SslCubit _sslCubit;
  late final _AppScopeNotifier _notifier;
  SshTarget? _lastTarget;

  @override
  void initState() {
    super.initState();
    _terminalCubit = TerminalCubit();
    _operationHistoryCubit = OperationHistoryCubit();
    _serversCubit = ServersCubit();
    _commandRunnerCubit = CommandRunnerCubit(
      terminalCubit: _terminalCubit,
      historyCubit: _operationHistoryCubit,
      currentTarget: () => _connectionCubit.target,
    );
    _connectionCubit = ConnectionCubit(
      commandRunnerCubit: _commandRunnerCubit,
      serversCubit: _serversCubit,
      terminalCubit: _terminalCubit,
      historyCubit: _operationHistoryCubit,
    );
    _packagesCubit = PackagesCubit(commandRunnerCubit: _commandRunnerCubit);
    _servicesCubit = ServicesCubit(
      commandRunnerCubit: _commandRunnerCubit,
      currentTarget: () => _connectionCubit.target,
    );
    _overviewCubit = OverviewCubit(commandRunnerCubit: _commandRunnerCubit);
    _nginxCubit = NginxCubit(commandRunnerCubit: _commandRunnerCubit);
    _sslCubit = SslCubit(commandRunnerCubit: _commandRunnerCubit);
    _notifier = _AppScopeNotifier([
      _terminalCubit,
      _operationHistoryCubit,
      _serversCubit,
      _commandRunnerCubit,
      _connectionCubit,
      _packagesCubit,
      _servicesCubit,
      _overviewCubit,
      _nginxCubit,
      _sslCubit,
    ]);
    _connectionCubit.addListener(_syncTargetScopedState);
    _load();
  }

  Future<void> _load() async {
    await _serversCubit.load();
    await _nginxCubit.load();
  }

  void _syncTargetScopedState() {
    final nextTarget = _connectionCubit.target;
    if (_sameTarget(_lastTarget, nextTarget)) {
      return;
    }
    _lastTarget = nextTarget;
    _overviewCubit.clear();
    _nginxCubit.clear();
    _sslCubit.clear();
    _servicesCubit.loadForTarget(nextTarget);
  }

  bool _sameTarget(SshTarget? left, SshTarget? right) {
    return left?.host == right?.host && left?.user == right?.user;
  }

  @override
  void dispose() {
    _connectionCubit.removeListener(_syncTargetScopedState);
    _notifier.dispose();
    _terminalCubit.dispose();
    _operationHistoryCubit.dispose();
    _serversCubit.dispose();
    _commandRunnerCubit.dispose();
    _connectionCubit.dispose();
    _packagesCubit.dispose();
    _servicesCubit.dispose();
    _overviewCubit.dispose();
    _nginxCubit.dispose();
    _sslCubit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppScopeInherited(
      notifier: _notifier,
      terminalCubit: _terminalCubit,
      operationHistoryCubit: _operationHistoryCubit,
      serversCubit: _serversCubit,
      commandRunnerCubit: _commandRunnerCubit,
      connectionCubit: _connectionCubit,
      packagesCubit: _packagesCubit,
      servicesCubit: _servicesCubit,
      overviewCubit: _overviewCubit,
      nginxCubit: _nginxCubit,
      sslCubit: _sslCubit,
      child: widget.child,
    );
  }
}

class _AppScopeNotifier extends ChangeNotifier {
  _AppScopeNotifier(this._listenables) {
    for (final listenable in _listenables) {
      listenable.addListener(notifyListeners);
    }
  }

  final List<Listenable> _listenables;

  @override
  void dispose() {
    for (final listenable in _listenables) {
      listenable.removeListener(notifyListeners);
    }
    super.dispose();
  }
}

class _AppScopeInherited extends InheritedNotifier<_AppScopeNotifier> {
  const _AppScopeInherited({
    required super.notifier,
    required super.child,
    required this.terminalCubit,
    required this.operationHistoryCubit,
    required this.serversCubit,
    required this.commandRunnerCubit,
    required this.connectionCubit,
    required this.packagesCubit,
    required this.servicesCubit,
    required this.overviewCubit,
    required this.nginxCubit,
    required this.sslCubit,
  });

  final TerminalCubit terminalCubit;
  final OperationHistoryCubit operationHistoryCubit;
  final ServersCubit serversCubit;
  final CommandRunnerCubit commandRunnerCubit;
  final ConnectionCubit connectionCubit;
  final PackagesCubit packagesCubit;
  final ServicesCubit servicesCubit;
  final OverviewCubit overviewCubit;
  final NginxCubit nginxCubit;
  final SslCubit sslCubit;
}
