import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/server_profile.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/packages/local_config/servers_store.dart';

void main() {
  test('saves and loads server profiles', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_test_');
    addTearDown(() => tempDir.delete(recursive: true));

    final store = ServersStore(paths: ConfigPaths(homeDirectory: tempDir.path));
    await store.save(const [
      ServerProfile(name: 'prod', host: '1.2.3.4', remark: 'main'),
    ]);

    final servers = await store.load();

    expect(servers, hasLength(1));
    expect(servers.single.name, 'prod');
    expect(servers.single.host, '1.2.3.4');
    expect(servers.single.user, 'root');
    expect(servers.single.remark, 'main');
  });
}
