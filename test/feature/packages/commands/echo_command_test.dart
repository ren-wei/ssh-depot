import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/commands/echo_command.dart';

void main() {
  test('builds quoted echo command', () {
    const command = EchoCommand('hello world', summary: '输出');

    expect(command.summary, '输出');
    expect(command.text, "echo 'hello world'");
  });

  test('quotes empty and single quote values', () {
    expect(const EchoCommand('').text, "echo ''");
    expect(const EchoCommand("a'b").text, "echo 'a'\"'\"'b'");
  });
}
