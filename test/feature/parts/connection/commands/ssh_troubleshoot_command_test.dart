import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/parts/connection/commands/ssh_troubleshoot_command.dart';

void main() {
  test('builds troubleshoot command with public key checks', () {
    final command = troubleshootCommandFor('ssh-ed25519 AAAA');

    expect(command, startsWith('set -u'));
    expect(command, contains('== SSH 连接排查 =='));
    expect(command, contains("expected_key='ssh-ed25519 AAAA'"));
    expect(command, contains('authorized_keys 已包含本机公钥'));
    expect(command, contains('sshd -T'));
  });

  test('builds troubleshoot command without public key', () {
    final command = troubleshootCommandFor(null);

    expect(command, contains("expected_key=''"));
    expect(command, contains('未带入本机公钥'));
  });
}
