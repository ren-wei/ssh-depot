import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/server_profile.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/packages/local_config/servers_store.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';
import 'package:ssh_depot/feature/utils/home_directory.dart';

class ServersCubit extends ChangeNotifier {
  ServersCubit()
      : _serversStore = ServersStore(
          paths: ConfigPaths(homeDirectory: resolveHomeDirectory()),
        );

  final ServersStore _serversStore;

  List<ServerProfile> servers = [];

  Future<void> load() async {
    servers = await _serversStore.load();
    notifyListeners();
  }

  Future<bool> saveServer(ServerProfile server) async {
    final existingIndex = servers.indexWhere((item) => item.host == server.host && item.user == server.user);
    final nextServers = [...servers];
    if (existingIndex >= 0) {
      nextServers[existingIndex] = server;
    } else {
      nextServers.add(server);
    }

    await _serversStore.save(nextServers);
    servers = nextServers;
    notifyListeners();
    return true;
  }

  Future<void> deleteServer(ServerProfile server) async {
    servers = [
      for (final item in servers)
        if (item.host != server.host || item.user != server.user) item,
    ];
    await _serversStore.save(servers);
    notifyListeners();
  }

  ServerProfile profileForSuccessfulConnect(String host, String user) {
    return servers.firstWhere(
      (server) => server.host == host && server.user == user,
      orElse: () => ServerProfile(name: host, host: host, user: user),
    );
  }

  String titleFor(SshTarget? target) {
    if (target == null) {
      return '';
    }
    for (final server in servers) {
      if (server.host == target.host && server.user == target.user && server.name.trim().isNotEmpty) {
        return server.name.trim();
      }
    }
    return target.address;
  }
}
