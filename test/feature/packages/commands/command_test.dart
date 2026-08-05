import 'package:flutter_test/flutter_test.dart';
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

  test('CommandWithSummary replaces summary without changing text', () {
    final command = CommandWithSummary(
      summary: '自定义说明',
      command: const EchoCommand('payload'),
    );

    expect(command.summary, '自定义说明');
    expect(command.text, "echo 'payload'");
  });
}
