import 'dart:io';

import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';

class PreferencesStore {
  const PreferencesStore({required ConfigPaths paths}) : _paths = paths;

  final ConfigPaths _paths;

  Future<bool> exists() {
    return File(_paths.preferencesFile).exists();
  }
}
