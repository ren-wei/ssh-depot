import '../../../core/process/local_process_runner.dart';
import '../../../core/process/process_output_chunk.dart';
import 'ssh_command.dart';
import 'ssh_target.dart';

class SshExecutor {
  const SshExecutor({required LocalProcessRunner processRunner}) : _processRunner = processRunner;

  final LocalProcessRunner _processRunner;

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
        target.address,
        command.command,
      ],
      timeout: command.timeout,
      onOutput: onOutput,
    );
  }
}
