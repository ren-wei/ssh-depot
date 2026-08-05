import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/commands/journalctl_command.dart';

void main() {
  test('builds journalctl unit command with no pager by default', () {
    final command = JournalctlCommand.unit('nginx.service');

    expect(command.summary, '查看服务日志');
    expect(command.text, "journalctl -u 'nginx.service' --no-pager -n 80");
  });

  test('supports custom line count and pager flag boundary', () {
    expect(
      JournalctlCommand.unit('docker.socket', lines: 0, noPager: false).text,
      "journalctl -u 'docker.socket' -n 0",
    );
  });
}
