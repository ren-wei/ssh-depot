import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/packages/local_config/service_preferences_store.dart';

void main() {
  test('loads nginx as default when file is missing or invalid', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_service_preferences_');
    addTearDown(() => tempDir.delete(recursive: true));
    final paths = ConfigPaths(homeDirectory: tempDir.path);
    final store = ServicePreferencesStore(paths: paths);

    expect(await store.load('root@host'), ['nginx.service']);
    await File(paths.preferencesFile).create(recursive: true);
    await File(paths.preferencesFile).writeAsString('- invalid');
    expect(await store.load('root@host'), ['nginx.service']);
  });

  test('saves and loads services by target with dedupe and sorting by target key', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_service_preferences_');
    addTearDown(() => tempDir.delete(recursive: true));
    final paths = ConfigPaths(homeDirectory: tempDir.path);
    final store = ServicePreferencesStore(paths: paths);

    await store.save('root@b', ['docker.service', 'docker.service', '']);
    await store.save('root@a', []);

    expect(await store.load('root@b'), ['docker.service']);
    expect(await store.load('root@a'), ['nginx.service']);
    expect(await File(paths.preferencesFile).readAsString(), startsWith('servicesByTarget:\n  "root@a":'));
  });

  test('loads legacy services list when servicesByTarget is absent', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_service_preferences_');
    addTearDown(() => tempDir.delete(recursive: true));
    final paths = ConfigPaths(homeDirectory: tempDir.path);
    await File(paths.preferencesFile).create(recursive: true);
    await File(paths.preferencesFile).writeAsString('services:\n  - nginx.service\n  - docker.service\n');

    expect(await ServicePreferencesStore(paths: paths).load('root@host'), ['nginx.service', 'docker.service']);
  });
}
