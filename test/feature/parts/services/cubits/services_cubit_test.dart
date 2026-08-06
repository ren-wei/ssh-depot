import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/packages/local_config/service_preferences_store.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';
import 'package:ssh_depot/feature/parts/services/cubits/services_cubit.dart';

import '../../../fake_remote_command_runner.dart';

void main() {
  test('loads watched services per target', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_services_');
    addTearDown(() => tempDir.delete(recursive: true));
    final store = ServicePreferencesStore(paths: ConfigPaths(homeDirectory: tempDir.path));
    await store.save('root@one.example.com', const ['nginx.service']);
    await store.save('root@two.example.com', const ['docker.service']);

    final runner = FakeRemoteCommandRunner();
    final cubit = ServicesCubit(
      commandRunner: runner,
      currentTarget: () => const SshTarget(host: 'one.example.com'),
      servicePreferencesStore: store,
    );

    await cubit.loadForTarget(const SshTarget(host: 'two.example.com'));

    expect(cubit.managedServices, ['docker.service']);
  });

  test('refreshes all managed service statuses after loading target', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_services_');
    addTearDown(() => tempDir.delete(recursive: true));
    final store = ServicePreferencesStore(paths: ConfigPaths(homeDirectory: tempDir.path));
    await store.save('root@one.example.com', const ['nginx.service', 'docker.service']);
    final runner = FakeRemoteCommandRunner()
      ..responses['获取 nginx 状态'] = const RemoteCommandResult(
        exitCode: 0,
        output: 'service=nginx.service;status=active;enabled=enabled\n',
      )
      ..responses['获取 docker 状态'] = const RemoteCommandResult(
        exitCode: 0,
        output: 'service=docker.service;status=inactive;enabled=disabled\n',
      );
    final cubit = ServicesCubit(
      commandRunner: runner,
      currentTarget: () => const SshTarget(host: 'one.example.com'),
      servicePreferencesStore: store,
    );

    await cubit.loadForTarget(const SshTarget(host: 'one.example.com'));
    await cubit.refreshManagedServiceStatuses();

    expect(cubit.serviceSnapshots['nginx.service']?.status, ServiceStatus.active);
    expect(cubit.serviceSnapshots['docker.service']?.enabled, isFalse);
    expect(runner.commands.where((command) => command.contains('systemctl is-active')), hasLength(2));
  });

  test('stop action refreshes status and logs', () async {
    final runner = FakeRemoteCommandRunner()
      ..responses['docker stop'] = const RemoteCommandResult(exitCode: 0, output: '')
      ..responses['获取 docker 状态'] = const RemoteCommandResult(
        exitCode: 0,
        output: 'service=docker.service;status=inactive;enabled=enabled\n',
      )
      ..responses['查看 docker 日志'] = const RemoteCommandResult(exitCode: 0, output: 'Stopped Docker\n');
    final cubit = ServicesCubit(
      commandRunner: runner,
      currentTarget: () => const SshTarget(host: 'one.example.com'),
    );

    await cubit.serviceAction('docker.service', 'stop');

    expect(cubit.serviceSnapshots['docker.service']?.status, ServiceStatus.inactive);
    expect(cubit.serviceLogsOutput, 'Stopped Docker\n');
    expect(runner.commands, contains("systemctl stop 'docker.service'"));
  });
}
