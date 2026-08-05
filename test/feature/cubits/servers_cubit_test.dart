import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/server_profile.dart';
import 'package:ssh_depot/feature/cubits/servers_cubit.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/packages/local_config/servers_store.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

void main() {
  test('saves updates deletes and loads servers', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_servers_cubit_');
    addTearDown(() => tempDir.delete(recursive: true));
    final cubit = ServersCubit(serversStore: ServersStore(paths: ConfigPaths(homeDirectory: tempDir.path)));

    await cubit.saveServer(const ServerProfile(name: 'prod', host: 'host'));
    await cubit.saveServer(const ServerProfile(name: 'prod-new', host: 'host'));
    expect(cubit.servers, hasLength(1));
    expect(cubit.servers.single.name, 'prod-new');

    await cubit.deleteServer(cubit.servers.single);
    expect(cubit.servers, isEmpty);

    await cubit.saveServer(const ServerProfile(name: 'prod', host: 'host'));
    final loaded = ServersCubit(serversStore: ServersStore(paths: ConfigPaths(homeDirectory: tempDir.path)));
    await loaded.load();
    expect(loaded.servers.single.host, 'host');
  });

  test('resolves profile and title for targets', () {
    final cubit = ServersCubit();
    cubit.servers = const [ServerProfile(name: 'prod', host: 'host', user: 'root')];

    expect(cubit.profileForSuccessfulConnect('host', 'root').name, 'prod');
    expect(cubit.profileForSuccessfulConnect('other', 'root').name, 'other');
    expect(cubit.titleFor(const SshTarget(host: 'host')), 'prod');
    expect(cubit.titleFor(const SshTarget(host: 'other', user: 'admin')), 'admin@other');
    expect(cubit.titleFor(null), '');
  });
}
