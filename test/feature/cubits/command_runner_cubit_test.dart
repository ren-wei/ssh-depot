import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/core/process/process_output_chunk.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/cubits/operation_history_cubit.dart';
import 'package:ssh_depot/feature/cubits/terminal_cubit.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/commands/echo_command.dart';
import 'package:ssh_depot/feature/packages/ssh/shell_session.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_command.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_executor.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

void main() {
  test('reports missing target without running command', () async {
    final executor = _FakeSshExecutor();
    final cubit = CommandRunnerCubit(
      terminalCubit: TerminalCubit(),
      historyCubit: OperationHistoryCubit(),
      currentTarget: () => null,
      sshExecutor: executor,
    );

    await cubit.runCommand(command: const EchoCommand('ok'));
    final result = await cubit.runCaptureCommand(
      command: CommandSequence(
        summary: 'Echo',
        commands: const [EchoCommand('ok')],
        parser: (result) => result,
      ),
    );

    expect(result, isNull);
    expect(executor.commands, isEmpty);
    expect(cubit.statusLine, '请先连接服务器');
  });

  test('runs command on target, appends output, records history and returns capture output', () async {
    final terminal = TerminalCubit();
    final history = OperationHistoryCubit();
    final executor = _FakeSshExecutor(output: 'done\n');
    final cubit = CommandRunnerCubit(
      terminalCubit: terminal,
      historyCubit: history,
      currentTarget: () => const SshTarget(host: 'host'),
      sshExecutor: executor,
    );

    final result = await cubit.runCaptureCommand(
      command: CommandSequence(
        summary: 'Echo',
        commands: const [EchoCommand('ok')],
        parser: (result) => result,
      ),
    );

    expect(result?.succeeded, isTrue);
    expect(result?.output, 'done\n');
    expect(executor.commands, ["echo 'ok'"]);
    expect(terminal.output, contains("\$ echo 'ok'"));
    expect(terminal.output, contains('done'));
    expect(terminal.terminalRawText, contains("\$ echo 'ok'\r\n"));
    expect(history.records.single.summary, 'Echo');
    expect(cubit.statusLine, '✓ Echo 成功');
    expect(cubit.isRunning, isFalse);
  });

  test('records failed command and supports cancel status', () async {
    final executor = _FakeSshExecutor(exitCode: 2, interruptResult: true);
    final cubit = CommandRunnerCubit(
      terminalCubit: TerminalCubit(),
      historyCubit: OperationHistoryCubit(),
      currentTarget: () => const SshTarget(host: 'host'),
      sshExecutor: executor,
    );

    await cubit.runCommand(command: const EchoCommand('bad'));
    cubit.cancelRunning();

    expect(cubit.statusLine, '操作已取消');
  });
}

class _FakeSshExecutor extends SshExecutor {
  _FakeSshExecutor({
    this.exitCode = 0,
    this.output = '',
    this.interruptResult = false,
  }) : super(session: _FakeShellSession());

  final int exitCode;
  final String output;
  final bool interruptResult;
  final List<String> commands = [];

  @override
  Future<int> openMaster({
    required SshTarget target,
    required void Function(ProcessOutputChunk chunk) onOutput,
    Duration? timeout,
  }) async {
    onOutput(ProcessOutputChunk(text: output, isStdErr: false));
    return exitCode;
  }

  @override
  Future<int> run({
    required SshTarget target,
    required SshCommand command,
    required void Function(ProcessOutputChunk chunk) onOutput,
  }) async {
    commands.add(command.command);
    onOutput(ProcessOutputChunk(text: output, isStdErr: false));
    return exitCode;
  }

  @override
  bool interruptActive() => interruptResult;

  @override
  Future<int> closeMaster({
    required SshTarget target,
    required void Function(ProcessOutputChunk chunk) onOutput,
  }) async {
    return 0;
  }
}

class _FakeShellSession implements ShellSession {
  @override
  bool get isOpen => true;

  @override
  void close() {}

  @override
  bool interrupt() => false;

  @override
  bool matches(SshTarget target) => true;

  @override
  Future<int> open({
    required SshTarget target,
    required void Function(ProcessOutputChunk chunk) onOutput,
    Duration? timeout,
  }) async {
    return 0;
  }

  @override
  Future<int> run({
    required String command,
    required void Function(ProcessOutputChunk chunk) onOutput,
    Duration? timeout,
  }) async {
    return 0;
  }
}
