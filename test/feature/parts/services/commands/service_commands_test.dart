import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/parts/services/commands/service_commands.dart';
import 'package:ssh_depot/feature/parts/services/parsers/service_parsers.dart';

void main() {
  test('normalizes managed services to systemd unit names', () {
    expect(
      normalizeManagedServices(['nginx', 'docker.service', 'nginx']),
      ['nginx.service', 'docker.service'],
    );
    expect(normalizeManagedServices(['bad name']), ['nginx.service']);
    expect(serviceUnitName(''), '');
    expect(isSafeServiceName('docker@one.service'), isTrue);
    expect(isSafeServiceName('bad/name.service'), isFalse);
  });

  test('builds nginx logs command with file fallback', () {
    final command = serviceLogsCommand('nginx.service');

    expect(command.text, contains('journalctl -u'));
    expect(command.text, contains('/var/log/nginx/error.log'));
    expect(command.text, contains('/var/log/nginx/access.log'));
  });

  test('parses systemd service list and removes duplicates', () {
    const output = '''
nginx.service enabled enabled
docker.socket enabled enabled
docker.service disabled disabled
nginx.service loaded active running A high performance web server
''';

    expect(parseSystemdServices(output), ['docker.service', 'nginx.service']);
  });

  test('parses service status snapshot', () {
    const output = 'service=docker.service;status=inactive;enabled=enabled\n';

    final snapshot = parseServiceSnapshot(output);

    expect(snapshot, isNotNull);
    expect(snapshot!.name, 'docker.service');
    expect(snapshot.status, ServiceStatus.inactive);
    expect(snapshot.enabled, isTrue);
  });

  test('builds service action commands and handles unknown action', () {
    expect(serviceActionCommand('nginx.service', 'start')?.text, "systemctl start 'nginx.service'");
    expect(serviceActionCommand('nginx.service', 'stop')?.summary, '停止服务');
    expect(serviceActionCommand('nginx.service', 'unknown'), isNull);
    expect(serviceActionSummary('unknown'), '服务操作');
  });

  test('predicts expected service status after actions', () {
    const previous = ServiceSnapshot(name: 'nginx.service', status: ServiceStatus.failed, enabled: true);

    expect(
      expectedServiceStatus(serviceUnit: 'nginx.service', action: 'stop', previous: previous).status,
      ServiceStatus.inactive,
    );
    expect(
      expectedServiceStatus(serviceUnit: 'nginx.service', action: 'restart', previous: previous).status,
      ServiceStatus.active,
    );
    expect(
      expectedServiceStatus(serviceUnit: 'nginx.service', action: 'status', previous: previous).status,
      ServiceStatus.failed,
    );
  });
}
