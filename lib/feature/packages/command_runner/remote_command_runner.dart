import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

abstract interface class RemoteCommandRunner {
  bool get isRunning;
  String get statusLine;

  Future<void> runCommand({
    required Command command,
    Duration? timeout,
  });

  Future<void> runRemote({
    required String summary,
    required String command,
    Duration? timeout,
  });

  Future<RemoteCommandResult?> runCaptureCommand({
    required Command command,
    Duration? timeout,
  });

  Future<RemoteCommandResult?> runCaptureRemote({
    required String summary,
    required String command,
    Duration? timeout,
  });

  Future<int> runCommandOnTarget({
    required SshTarget target,
    required Command command,
    Duration? timeout,
  });

  Future<int> runOnTarget({
    required SshTarget target,
    required String summary,
    required String command,
    Duration? timeout,
  });

  void setStatus(String value);
}
