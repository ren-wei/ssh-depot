import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/parts/overview/parsers/overview_parser.dart';

void main() {
  test('parses overview snapshot output', () {
    const output = '''
distribution=Debian GNU/Linux 12 (bookworm)
kernel=6.1.0-18-amd64
uptime=up 18 days, 2 hours
cpu=24
memory=61
disk=42
service=nginx;status=active;enabled=enabled
service=mysql;status=failed;enabled=disabled
service=redis;status=inactive;enabled=unknown
''';

    final snapshot = const OverviewParser().parse(output);

    expect(snapshot.distribution, 'Debian GNU/Linux 12 (bookworm)');
    expect(snapshot.kernel, '6.1.0-18-amd64');
    expect(snapshot.uptime, 'up 18 days, 2 hours');
    expect(snapshot.cpuPercent, 24);
    expect(snapshot.memoryPercent, 61);
    expect(snapshot.diskPercent, 42);
    expect(snapshot.activeServiceCount, 1);
    expect(snapshot.services, hasLength(3));
    expect(snapshot.services[0].name, 'nginx');
    expect(snapshot.services[0].status, ServiceStatus.active);
    expect(snapshot.services[0].enabled, isTrue);
    expect(snapshot.services[1].status, ServiceStatus.failed);
    expect(snapshot.services[1].enabled, isFalse);
    expect(snapshot.services[2].status, ServiceStatus.inactive);
    expect(snapshot.services[2].enabled, isNull);
  });

  test('uses defaults and clamps percent boundaries', () {
    const output = '''
cpu=-1
memory=88.6
disk=180
service=;status=active;enabled=enabled
service=nginx.service;status=activating;enabled=static
''';

    final snapshot = const OverviewParser().parse(output);

    expect(snapshot.distribution, '--');
    expect(snapshot.kernel, '--');
    expect(snapshot.uptime, '--');
    expect(snapshot.cpuPercent, 0);
    expect(snapshot.memoryPercent, 89);
    expect(snapshot.diskPercent, 100);
    expect(snapshot.services, hasLength(1));
    expect(snapshot.services.single.status, ServiceStatus.activating);
    expect(snapshot.services.single.enabled, isNull);
  });

  test('ignores malformed lines and invalid percent values', () {
    final snapshot = const OverviewParser().parse('noise\n=bad\ncpu=abc\n');

    expect(snapshot.cpuPercent, isNull);
    expect(snapshot.services, isEmpty);
  });
}
