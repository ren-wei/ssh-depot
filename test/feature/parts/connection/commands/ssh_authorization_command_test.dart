import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/parts/connection/commands/ssh_authorization_command.dart';

void main() {
  test('builds authorized_keys append command with quoted public key', () {
    final command = authorizationCommandFor("ssh-ed25519 AAAA user'host");

    expect(command, contains('mkdir -p ~/.ssh'));
    expect(command, contains('chmod 700 ~/.ssh'));
    expect(command, contains('chmod 600 ~/.ssh/authorized_keys'));
    expect(command, contains("'ssh-ed25519 AAAA user'\"'\"'host'"));
  });
}
