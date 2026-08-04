import '../../../core/process/local_process_runner.dart';
import '../../../core/process/process_output_chunk.dart';
import 'pty_ssh_session.dart';
import 'ssh_command.dart';
import 'ssh_target.dart';

class SshExecutor {
  SshExecutor({required LocalProcessRunner processRunner}) : _processRunner = processRunner;

  final LocalProcessRunner _processRunner;
  final PtySshSession _ptySession = PtySshSession();

  Future<int> openMaster({
    required SshTarget target,
    required void Function(ProcessOutputChunk chunk) onOutput,
    Duration? timeout,
  }) {
    return _ptySession.open(
      target: target,
      timeout: timeout,
      onOutput: onOutput,
    );
  }

  Future<int> closeMaster({
    required SshTarget target,
    required void Function(ProcessOutputChunk chunk) onOutput,
  }) {
    _ptySession.close();
    return Future.value(0);
  }

  Future<int> run({
    required SshTarget target,
    required SshCommand command,
    required void Function(ProcessOutputChunk chunk) onOutput,
  }) async {
    if (!_ptySession.matches(target) || !_ptySession.isOpen) {
      final openExitCode = await _ptySession.open(
        target: target,
        timeout: const Duration(seconds: 12),
        onOutput: onOutput,
      );
      if (openExitCode != 0) {
        return openExitCode;
      }
    }
    return _ptySession.run(
      command: command.command,
      timeout: command.timeout,
      onOutput: onOutput,
    );
  }

  bool interruptActive() {
    return _ptySession.interrupt() || _processRunner.killActive();
  }

  Future<int> runDetached({
    required SshTarget target,
    required SshCommand command,
    required void Function(ProcessOutputChunk chunk) onOutput,
  }) {
    return _processRunner.start(
      executable: 'ssh',
      arguments: [
        '-o',
        'BatchMode=yes',
        '-o',
        'ConnectTimeout=10',
        if (target.controlPath != null && target.controlPath!.isNotEmpty) ...[
          '-S',
          target.controlPath!,
          '-o',
          'ControlMaster=no',
        ],
        target.address,
        command.command,
      ],
      timeout: command.timeout,
      onOutput: onOutput,
    );
  }
}
