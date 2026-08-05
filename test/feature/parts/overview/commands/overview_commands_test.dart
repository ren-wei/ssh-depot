import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/parts/overview/commands/overview_commands.dart';

void main() {
  test('builds overview command for watched services', () {
    final command = overviewCommandFor(const ['nginx.service', 'docker.service']);

    expect(command.text, contains('printf "distribution=%s'));
    expect(command.text, contains("for svc in 'nginx.service' 'docker.service'; do"));
    expect(command.text, contains('systemctl is-active'));
  });
}
