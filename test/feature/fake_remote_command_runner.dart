import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/command_runner/remote_command_runner.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

class FakeRemoteCommandRunner implements RemoteCommandRunner {
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
  Future<void> runRemote({
    required String summary,
    required String command,
    Duration? timeout,
  }) async {
    commands.add(command);
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
  Future<RemoteCommandResult?> runCaptureRemote({
    required String summary,
    required String command,
    Duration? timeout,
  }) async {
    commands.add(command);
    return responses[summary] ?? const RemoteCommandResult(exitCode: 0, output: '');
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
  Future<int> runOnTarget({
    required SshTarget target,
    required String summary,
    required String command,
    Duration? timeout,
  }) async {
    commands.add(command);
    return responses[summary]?.exitCode ?? 0;
  }

  @override
  void setStatus(String value) {
    statusLine = value;
  }
}
