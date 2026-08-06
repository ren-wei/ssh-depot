import 'package:flutter/foundation.dart';
import 'package:ssh_depot/core/process/local_process_runner.dart';
import 'package:ssh_depot/core/process/process_output_chunk.dart';
import 'package:ssh_depot/feature/cubits/terminal_cubit.dart';
import 'package:ssh_depot/feature/packages/ssh/pty_ssh_session.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_command.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_executor.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

class AppConnectionCubit extends ChangeNotifier {
  AppConnectionCubit({TerminalCubit? terminalCubit})
      : _sshExecutor = SshExecutor(
          session: PtySshSession(),
          processRunner: LocalProcessRunner(),
        ),
        _terminalCubit = terminalCubit ?? TerminalCubit();

  final SshExecutor _sshExecutor;
  final TerminalCubit _terminalCubit;

  SshTarget? target;
  String statusLine = '空闲';
  bool isTesting = false;

  bool get hasTarget => target != null;

  void requestConnect(String host, {String user = 'root'}) {
    final cleanHost = host.trim();
    final cleanUser = user.trim().isEmpty ? 'root' : user.trim();
    if (cleanHost.isEmpty) {
      statusLine = '请输入 Host';
      notifyListeners();
      return;
    }
    target = SshTarget(
      host: cleanHost,
      user: cleanUser,
      controlPath: _controlPathFor(cleanHost, cleanUser),
    );
    statusLine = '正在连接 $cleanUser@$cleanHost';
    notifyListeners();
  }

  Future<bool> testConnection(String host, {String user = 'root'}) async {
    final cleanHost = host.trim();
    final cleanUser = user.trim().isEmpty ? 'root' : user.trim();
    if (cleanHost.isEmpty) {
      statusLine = '请输入 Host';
      notifyListeners();
      return false;
    }

    final testTarget = SshTarget(
      host: cleanHost,
      user: cleanUser,
      controlPath: _controlPathFor(cleanHost, cleanUser),
    );

    isTesting = true;
    _terminalCubit.clear();
    statusLine = '测试连接中 $cleanUser@$cleanHost';
    notifyListeners();

    int exitCode;
    try {
      exitCode = await _sshExecutor.openMaster(
        target: testTarget,
        timeout: const Duration(seconds: 12),
        onOutput: _appendTerminalOutput,
      );
      if (exitCode == 0) {
        exitCode = await _sshExecutor.run(
          target: testTarget,
          command: const SshCommand(
            summary: '测试连接',
            command: 'echo __ssh-depot_ok__',
            timeout: Duration(seconds: 12),
          ),
          onOutput: _appendTerminalOutput,
        );
      }
    } catch (error) {
      exitCode = -1;
      _appendTerminalOutput(ProcessOutputChunk(text: '$error\n', isStdErr: true));
      statusLine = '✗ 测试连接失败: $error';
      isTesting = false;
      notifyListeners();
      return false;
    } finally {
      await _sshExecutor.closeMaster(target: testTarget, onOutput: _appendTerminalOutput);
    }

    isTesting = false;
    statusLine = exitCode == 0 ? '✓ $cleanUser@$cleanHost 测试通过' : '✗ $cleanUser@$cleanHost 测试失败';
    notifyListeners();
    return exitCode == 0;
  }

  void markConnected() {
    final current = target;
    if (current == null) {
      return;
    }
    statusLine = '✓ ${current.address} 已连接';
    notifyListeners();
  }

  void failConnection(String message) {
    target = null;
    statusLine = message;
    notifyListeners();
  }

  void disconnect() {
    target = null;
    statusLine = '已断开';
    notifyListeners();
  }

  void setStatus(String value) {
    statusLine = value;
    notifyListeners();
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

  void _appendTerminalOutput(ProcessOutputChunk chunk) {
    _terminalCubit.appendOutput(chunk);
  }
}
