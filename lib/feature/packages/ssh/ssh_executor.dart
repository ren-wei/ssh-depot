import '../../../core/process/local_process_runner.dart';
import '../../../core/process/process_output_chunk.dart';
import 'ssh_command.dart';
import 'ssh_target.dart';

class SshExecutor {
  const SshExecutor({required LocalProcessRunner processRunner}) : _processRunner = processRunner;

  final LocalProcessRunner _processRunner;

  Future<int> openMaster({
    required SshTarget target,
    required void Function(ProcessOutputChunk chunk) onOutput,
    Duration? timeout,
  }) {
    final controlPath = target.controlPath;
    if (controlPath == null || controlPath.isEmpty) {
      throw ArgumentError('controlPath is required to open SSH master connection.');
    }

    return _processRunner.start(
      executable: 'ssh',
      arguments: [
        '-o',
        'BatchMode=yes',
        '-o',
        'ConnectTimeout=10',
        '-o',
        'ControlMaster=yes',
        '-o',
        'ControlPersist=yes',
        '-S',
        controlPath,
        '-N',
        '-f',
        target.address,
      ],
      timeout: timeout,
      onOutput: onOutput,
    );
  }

  Future<int> closeMaster({
    required SshTarget target,
    required void Function(ProcessOutputChunk chunk) onOutput,
  }) {
    final controlPath = target.controlPath;
    if (controlPath == null || controlPath.isEmpty) {
      return Future.value(0);
    }

    return _processRunner.start(
      executable: 'ssh',
      arguments: [
        '-S',
        controlPath,
        '-O',
        'exit',
        target.address,
      ],
      onOutput: onOutput,
    );
  }

  Future<int> run({
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
