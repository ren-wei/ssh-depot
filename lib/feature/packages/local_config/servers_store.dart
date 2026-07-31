import 'dart:io';

import '../../classes/server_profile.dart';
import 'config_paths.dart';

class ServersStore {
  const ServersStore({required ConfigPaths paths}) : _paths = paths;

  final ConfigPaths _paths;

  Future<List<ServerProfile>> load() async {
    final file = File(_paths.serversFile);
    if (!await file.exists()) {
      return const [];
    }

    // YAML parsing is intentionally deferred until the persistence schema is finalized.
    return const [];
  }
}
