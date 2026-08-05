import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/config.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';

void main() {
  test('builds local config paths under home directory', () {
    const paths = ConfigPaths(homeDirectory: '/home/me');

    expect(paths.configDirectory, '/home/me/${AppConfig.localConfigDirName}');
    expect(paths.serversFile, '/home/me/${AppConfig.localConfigDirName}/servers.yaml');
    expect(paths.templatesDirectory, '/home/me/${AppConfig.localConfigDirName}/templates');
    expect(paths.preferencesFile, '/home/me/${AppConfig.localConfigDirName}/preferences.yaml');
    expect(
      paths.servicePreferencesFile('root@example.com'),
      '/home/me/${AppConfig.localConfigDirName}/servers/root@example.com/services.yaml',
    );
    expect(
      paths.operationHistoryFile('root@example.com'),
      '/home/me/${AppConfig.localConfigDirName}/servers/root@example.com/operation_history.yaml',
    );
  });
}
