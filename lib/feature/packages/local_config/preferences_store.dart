import 'dart:io';

import 'config_paths.dart';

class PreferencesStore {
  const PreferencesStore({required ConfigPaths paths}) : _paths = paths;

  final ConfigPaths _paths;

  Future<bool> exists() {
    return File(_paths.preferencesFile).exists();
  }
}
