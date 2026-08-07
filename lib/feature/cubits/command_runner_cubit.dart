import 'package:flutter/foundation.dart';
import 'package:ssh_depot/core/process/local_process_runner.dart';
import 'package:ssh_depot/core/process/process_output_chunk.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/cubits/operation_history_cubit.dart';
import 'package:ssh_depot/feature/cubits/terminal_cubit.dart';
import 'package:ssh_depot/feature/packages/command_runner/operation_queue.dart';
import 'package:ssh_depot/feature/packages/command_runner/command_runner.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/ssh/pty_ssh_session.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_command.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_executor.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

class CommandRunnerCubit extends ChangeNotifier implements CommandRunner {
  CommandRunnerCubit({
    required TerminalCubit terminalCubit,
    required OperationHistoryCubit historyCubit,
    required SshTarget? Function() currentTarget,
    SshExecutor? sshExecutor,
    OperationQueue? queue,
  })  : _terminalCubit = terminalCubit,
        _historyCubit = historyCubit,
        _currentTarget = currentTarget,
        _queue = queue ?? OperationQueue(),
        _sshExecutor = sshExecutor ??
            SshExecutor(
              session: PtySshSession(),
              processRunner: LocalProcessRunner(),
            );

  final TerminalCubit _terminalCubit;
  final OperationHistoryCubit _historyCubit;
  final SshTarget? Function() _currentTarget;
  final OperationQueue _queue;
  final SshExecutor _sshExecutor;

  @override
  bool isRunning = false;

  @override
  String statusLine = '空闲';

  Future<int> openMasterAndVerify(SshTarget target) {
    return _queue.run(() async {
      isRunning = true;
      _setStatus('建立 SSH 连接');

      int exitCode;
      try {
        exitCode = await _sshExecutor.openMaster(
          target: target,
          timeout: const Duration(seconds: 12),
          onOutput: _appendOutput,
        );
        if (exitCode == 0) {
          exitCode = await _sshExecutor.run(
            target: target,
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
        _terminalCubit.append('$error\n');
      }

      if (exitCode != 0) {
        closeMaster(target);
      }
      isRunning = false;
      _setStatus(exitCode == 0 ? '✓ 建立 SSH 连接成功' : '✗ 建立 SSH 连接失败');
      return exitCode;
    });
  }

  @override
  Future<void> runCommand({
    required Command command,
    Duration? timeout,
  }) async {
    final target = _currentTarget();
    if (target == null) {
      _setStatus('请先连接服务器');
      return;
    }
    await _runOnTarget(
      target: target,
      summary: command.summary,
      command: command.text,
      timeout: timeout,
    );
  }

  @override
  Future<RemoteCommandResult?> runCaptureCommand({
    required Command command,
    Duration? timeout,
  }) async {
    final target = _currentTarget();
    if (target == null) {
      _setStatus('请先连接服务器');
      return null;
    }

    final output = StringBuffer();
    final exitCode = await _runOnTarget(
      target: target,
      summary: command.summary,
      command: command.text,
      timeout: timeout,
      onOutput: (chunk) => output.write(chunk.text),
    );
    return RemoteCommandResult(exitCode: exitCode, output: output.toString());
  }

  @override
  Future<int> runCommandOnTarget({
    required SshTarget target,
    required Command command,
    Duration? timeout,
  }) {
    return _runOnTarget(
      target: target,
      summary: command.summary,
      command: command.text,
      timeout: timeout,
    );
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
      _appendCommandInput(command);
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
        _terminalCubit.append('$error\n');
      }

      isRunning = false;
      _historyCubit.record(summary: summary, command: command, exitCode: exitCode);
      _setStatus(exitCode == 0 ? '✓ $summary 成功' : '✗ $summary 失败');
      return exitCode;
    });
  }

  void _appendCommandInput(String command) {
    final cleanCommand = command.trimRight();
    if (cleanCommand.isEmpty) {
      return;
    }
    _terminalCubit.append('\n\$ $cleanCommand\n');
  }

  void cancelRunning() {
    if (_sshExecutor.interruptActive()) {
      isRunning = false;
      _setStatus('操作已取消');
    }
  }

  void closeMaster(SshTarget target, {bool appendOutput = true}) {
    _sshExecutor
        .closeMaster(
          target: target,
          onOutput: appendOutput ? _appendOutput : (_) {},
        )
        .catchError((Object _) => 255);
  }

  @override
  void setStatus(String value) {
    _setStatus(value);
  }

  void _appendOutput(ProcessOutputChunk chunk) {
    _terminalCubit.appendOutput(chunk);
    if (isRunning && _terminalCubit.lastVisibleLine.isNotEmpty) {
      statusLine = _terminalCubit.lastVisibleLine;
      notifyListeners();
    }
  }

  void _setStatus(String value) {
    statusLine = value;
    notifyListeners();
  }
}
