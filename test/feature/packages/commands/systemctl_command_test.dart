import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/commands/systemctl_command.dart';

void main() {
  test('builds service action commands', () {
    expect(SystemctlCommand.start('nginx.service').text, "systemctl start 'nginx.service'");
    expect(SystemctlCommand.stop('nginx.service').text, "systemctl stop 'nginx.service'");
    expect(SystemctlCommand.restart('nginx.service').text, "systemctl restart 'nginx.service'");
    expect(SystemctlCommand.reload('nginx').text, "systemctl reload 'nginx'");
  });

  test('builds status list and snapshot commands', () {
    expect(SystemctlCommand.status('docker.service').text, "systemctl status 'docker.service' --no-pager");
    expect(SystemctlCommand.status('docker.service', noPager: false).text, "systemctl status 'docker.service'");
    expect(SystemctlCommand.listServices().text, contains('systemctl list-unit-files --type=service'));
    expect(SystemctlCommand.serviceSnapshot('docker.service').text,
        contains('printf "service=%s;status=%s;enabled=%s\\n"'));
    expect(SystemctlCommand.serviceSnapshot('docker.service').text, contains("'docker.service'"));
  });
}
