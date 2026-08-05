import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_command.dart';

void main() {
  test('stores ssh command fields and optional timeout', () {
    const command = SshCommand(command: 'uptime', summary: '查看 uptime', timeout: Duration(seconds: 3));

    expect(command.command, 'uptime');
    expect(command.summary, '查看 uptime');
    expect(command.timeout, const Duration(seconds: 3));
    expect(const SshCommand(command: 'true', summary: 'ok').timeout, isNull);
  });
}
