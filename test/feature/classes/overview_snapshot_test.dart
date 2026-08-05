import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';

void main() {
  test('counts only active services and removes service suffix for display', () {
    const snapshot = OverviewSnapshot(
      distribution: 'Debian',
      kernel: '6.1',
      uptime: 'up',
      cpuPercent: null,
      memoryPercent: null,
      diskPercent: null,
      services: [
        ServiceSnapshot(name: 'nginx.service', status: ServiceStatus.active, enabled: true),
        ServiceSnapshot(name: 'docker.service', status: ServiceStatus.inactive, enabled: true),
        ServiceSnapshot(name: 'redis', status: ServiceStatus.active, enabled: null),
      ],
    );

    expect(snapshot.activeServiceCount, 2);
    expect(snapshot.services.first.displayName, 'nginx');
    expect(serviceDisplayName('redis'), 'redis');
  });

  test('maps every service status label', () {
    expect(ServiceStatus.values.map((status) => status.label), [
      '运行中',
      '未运行',
      '失败',
      '启动中',
      '停止中',
      '未知',
    ]);
  });

  test('operation record succeeds only on zero exit code', () {
    expect(
      OperationRecord(timestamp: DateTime(2026), summary: 'ok', command: 'true', exitCode: 0).succeeded,
      isTrue,
    );
    expect(
      OperationRecord(timestamp: DateTime(2026), summary: 'fail', command: 'false', exitCode: 1).succeeded,
      isFalse,
    );
  });
}
