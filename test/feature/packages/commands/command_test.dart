import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/commands/echo_command.dart';

void main() {
  test('CommandSequence joins commands with default operator', () {
    final command = CommandSequence(
      summary: '组合',
      commands: const [EchoCommand('one'), EchoCommand('two')],
    );

    expect(command.summary, '组合');
    expect(command.text, "echo 'one' && echo 'two'");
  });

  test('CommandSequence supports custom operator and empty sequence boundary', () {
    expect(
      CommandSequence(
        summary: '分段',
        operator: ';',
        commands: const [EchoCommand('one'), EchoCommand('two')],
      ).text,
      "echo 'one' ; echo 'two'",
    );
    expect(const CommandSequence(summary: '空', commands: []).text, '');
  });

  test('CommandSequence capture parses combined output', () {
    final command = CommandSequence(
      summary: '解析组合',
      operator: ';',
      commands: const [EchoCommand('one'), EchoCommand('two')],
      parser: (result) {
        if (!result.succeeded) {
          return null;
        }
        return result.output.trim().split('\n');
      },
    );

    expect(command.summary, '解析组合');
    expect(command.text, "echo 'one' ; echo 'two'");
    expect(
      command.parse(const RemoteCommandResult(exitCode: 0, output: 'one\ntwo\n')),
      ['one', 'two'],
    );
    expect(command.parse(const RemoteCommandResult(exitCode: 1, output: 'bad')), isNull);
  });
}
