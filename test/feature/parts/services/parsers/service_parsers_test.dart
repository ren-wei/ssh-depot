import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/parts/services/parsers/service_parsers.dart';

void main() {
  test('parses only valid service units and sorts them', () {
    const output = '''
docker.socket loaded
nginx.service enabled
bad name.service enabled
ssh.service enabled
''';

    expect(parseSystemdServices(output), ['nginx.service', 'ssh.service']);
  });

  test('parses all known service status values', () {
    for (final entry in {
      'active': ServiceStatus.active,
      'inactive': ServiceStatus.inactive,
      'failed': ServiceStatus.failed,
      'activating': ServiceStatus.activating,
      'deactivating': ServiceStatus.deactivating,
      'other': ServiceStatus.unknown,
    }.entries) {
      final snapshot = parseServiceSnapshot('service=x.service;status=${entry.key};enabled=disabled');
      expect(snapshot?.status, entry.value);
      expect(snapshot?.enabled, isFalse);
    }
  });

  test('returns null for malformed snapshot output', () {
    expect(parseServiceSnapshot('status=active;enabled=enabled'), isNull);
    expect(parseServiceSnapshot(''), isNull);
  });
}
