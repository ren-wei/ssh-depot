import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/packages/local_config/preferences_store.dart';

void main() {
  test('reports whether preferences file exists', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_preferences_');
    addTearDown(() => tempDir.delete(recursive: true));
    final paths = ConfigPaths(homeDirectory: tempDir.path);
    final store = PreferencesStore(paths: paths);

    expect(await store.exists(), isFalse);
    await File(paths.preferencesFile).create(recursive: true);
    expect(await store.exists(), isTrue);
  });
}
