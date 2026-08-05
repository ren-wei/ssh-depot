import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/commands/apt_command.dart';

void main() {
  test('builds apt update install and remove commands', () {
    expect(AptCommand.update().text, 'apt update');
    expect(AptCommand.install('nginx').text, "apt install -y 'nginx'");
    expect(AptCommand.remove('nginx').text, "apt remove -y 'nginx'");
  });

  test('quotes package values with shell-sensitive characters', () {
    expect(AptCommand.install("lib'a").text, "apt install -y 'lib'\"'\"'a'");
  });
}
