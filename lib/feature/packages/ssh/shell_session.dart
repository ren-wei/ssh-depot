import 'package:ssh_depot/core/process/process_output_chunk.dart';

import 'ssh_target.dart';

abstract interface class ShellSession {
  bool get isOpen;

  bool matches(SshTarget target);

  Future<int> open({
    required SshTarget target,
    required void Function(ProcessOutputChunk chunk) onOutput,
    Duration? timeout,
  });

  Future<int> run({
    required String command,
    required void Function(ProcessOutputChunk chunk) onOutput,
    Duration? timeout,
  });

  bool interrupt();

  void close();
}
