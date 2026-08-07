import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/command_runner/command_runner.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

class FakeCommandRunner implements CommandRunner {
  final responses = <String, RemoteCommandResult>{};
  final commands = <String>[];

  @override
  bool isRunning = false;

  @override
  String statusLine = '空闲';

  @override
  Future<void> runCommand({
    required Command command,
    Duration? timeout,
  }) async {
    commands.add(command.text);
  }

  @override
  Future<RemoteCommandResult?> runCaptureCommand({
    required Command command,
    Duration? timeout,
  }) async {
    commands.add(command.text);
    return responses[command.summary] ?? const RemoteCommandResult(exitCode: 0, output: '');
  }

  @override
  Future<int> runCommandOnTarget({
    required SshTarget target,
    required Command command,
    Duration? timeout,
  }) async {
    commands.add(command.text);
    return responses[command.summary]?.exitCode ?? 0;
  }

  @override
  void setStatus(String value) {
    statusLine = value;
  }
}
