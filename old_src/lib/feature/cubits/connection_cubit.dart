import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/server_profile.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/cubits/operation_history_cubit.dart';
import 'package:ssh_depot/feature/cubits/servers_cubit.dart';
import 'package:ssh_depot/feature/cubits/terminal_cubit.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

class ConnectionCubit extends ChangeNotifier {
  ConnectionCubit({
    required CommandRunnerCubit commandRunnerCubit,
    required ServersCubit serversCubit,
    required TerminalCubit terminalCubit,
    required OperationHistoryCubit historyCubit,
  })  : _commandRunnerCubit = commandRunnerCubit,
        _serversCubit = serversCubit,
        _terminalCubit = terminalCubit,
        _historyCubit = historyCubit;

  final CommandRunnerCubit _commandRunnerCubit;
  final ServersCubit _serversCubit;
  final TerminalCubit _terminalCubit;
  final OperationHistoryCubit _historyCubit;

  SshTarget? target;

  bool get isConnected => target != null;

  Future<bool> testConnection(String host, {String user = 'root'}) async {
    final cleanHost = host.trim();
    final cleanUser = user.trim().isEmpty ? 'root' : user.trim();
    if (cleanHost.isEmpty) {
      _commandRunnerCubit.setStatus('请输入 Host');
      return false;
    }
    final nextTarget = SshTarget(host: cleanHost, user: cleanUser);
    final exitCode = await _commandRunnerCubit.testTarget(nextTarget, closeAfterTest: target == null);
    return exitCode == 0;
  }

  Future<void> connect(String host, {String user = 'root'}) async {
    final cleanHost = host.trim();
    final cleanUser = user.trim().isEmpty ? 'root' : user.trim();
    if (cleanHost.isEmpty) {
      _commandRunnerCubit.setStatus('请输入 Host');
      return;
    }

    final previousTarget = target;
    if (previousTarget != null) {
      _commandRunnerCubit.closeMaster(previousTarget, appendOutput: false);
    }
    target = null;
    _clearRuntime();
    notifyListeners();

    final nextTarget = SshTarget(
      host: cleanHost,
      user: cleanUser,
      controlPath: _controlPathFor(cleanHost, cleanUser),
    );
    final exitCode = await _commandRunnerCubit.openMasterAndVerify(nextTarget);
    if (exitCode == 0) {
      target = nextTarget;
      await _serversCubit.saveServer(_serversCubit.profileForSuccessfulConnect(cleanHost, cleanUser));
      _commandRunnerCubit.setStatus('✓ $cleanUser@$cleanHost 已连接');
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    final currentTarget = target;
    target = null;
    _clearRuntime();
    _commandRunnerCubit.setStatus('已断开');
    notifyListeners();
    if (currentTarget != null) {
      _commandRunnerCubit.closeMaster(currentTarget, appendOutput: false);
    }
  }

  Future<void> deleteConnectedServerIfMatches(ServerProfile server) async {
    if (target?.host == server.host && target?.user == server.user) {
      await disconnect();
    }
  }

  void _clearRuntime() {
    _terminalCubit.clear();
    _historyCubit.clear();
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
}
