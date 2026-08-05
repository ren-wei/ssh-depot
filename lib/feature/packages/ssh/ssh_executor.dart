import 'package:ssh_depot/core/process/local_process_runner.dart';
import 'package:ssh_depot/core/process/process_output_chunk.dart';

import 'shell_session.dart';
import 'ssh_command.dart';
import 'ssh_target.dart';

class SshExecutor {
  SshExecutor({
    required ShellSession session,
    LocalProcessRunner? processRunner,
  })  : _session = session,
        _processRunner = processRunner ?? LocalProcessRunner();

  final ShellSession _session;
  final LocalProcessRunner _processRunner;

  Future<int> openMaster({
    required SshTarget target,
    required void Function(ProcessOutputChunk chunk) onOutput,
    Duration? timeout,
  }) {
    return _session.open(target: target, timeout: timeout, onOutput: onOutput);
  }

  Future<int> closeMaster({
    required SshTarget target,
    required void Function(ProcessOutputChunk chunk) onOutput,
  }) async {
    _session.close();
    return 0;
  }

  Future<int> run({
    required SshTarget target,
    required SshCommand command,
    required void Function(ProcessOutputChunk chunk) onOutput,
  }) async {
    if (!_session.matches(target) || !_session.isOpen) {
      final openExitCode = await _session.open(
        target: target,
        timeout: const Duration(seconds: 12),
        onOutput: onOutput,
      );
      if (openExitCode != 0) {
        return openExitCode;
      }
    }
    return _session.run(
      command: command.command,
      timeout: command.timeout,
      onOutput: onOutput,
    );
  }

  bool interruptActive() {
    return _session.interrupt() || _processRunner.killActive();
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
