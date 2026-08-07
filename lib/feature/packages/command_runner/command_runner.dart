import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

abstract interface class CommandRunner {
  bool get isRunning;
  String get statusLine;

  Future<void> runCommand({
    required Command command,
    Duration? timeout,
  });

  Future<T?> runCaptureCommand<T>({
    required Command command,
    Duration? timeout,
  });

  Future<int> runCommandOnTarget({
    required SshTarget target,
    required Command command,
    Duration? timeout,
  });

  void setStatus(String value);
}
