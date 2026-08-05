import 'package:path/path.dart' as p;

import 'package:ssh_depot/feature/config.dart';

class ConfigPaths {
  const ConfigPaths({required this.homeDirectory});

  final String homeDirectory;

  String get configDirectory => p.join(homeDirectory, AppConfig.localConfigDirName);
  String get serversFile => p.join(configDirectory, 'servers.yaml');
  String get templatesDirectory => p.join(configDirectory, 'templates');
  String get preferencesFile => p.join(configDirectory, 'preferences.yaml');
  String servicePreferencesFile(String serverKey) {
    return p.join(configDirectory, 'servers', serverKey, 'services.yaml');
  }

  String operationHistoryFile(String serverKey) {
    return p.join(configDirectory, 'servers', serverKey, 'operation_history.yaml');
  }
}
