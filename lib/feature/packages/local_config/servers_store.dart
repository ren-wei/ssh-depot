import 'dart:io';

import 'package:yaml/yaml.dart';

import 'package:ssh_depot/feature/classes/server_profile.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';

class ServersStore {
  const ServersStore({required ConfigPaths paths}) : _paths = paths;

  final ConfigPaths _paths;

  Future<List<ServerProfile>> load() async {
    final file = File(_paths.serversFile);
    if (!await file.exists()) {
      return const [];
    }

    final parsed = loadYaml(await file.readAsString());
    if (parsed is! YamlList) {
      return const [];
    }

    return [
      for (final item in parsed)
        if (item is YamlMap)
          ServerProfile(
            name: item['name']?.toString() ?? '',
            host: item['host']?.toString() ?? '',
            user: item['user']?.toString() ?? 'root',
            remark: item['remark']?.toString(),
          ),
    ].where((server) => server.host.isNotEmpty).toList(growable: false);
  }

  Future<void> save(List<ServerProfile> servers) async {
    final file = File(_paths.serversFile);
    await file.parent.create(recursive: true);
    await file.writeAsString(_encodeServers(servers));
  }

  String _encodeServers(List<ServerProfile> servers) {
    final buffer = StringBuffer();
    for (final server in servers) {
      buffer.writeln('- name: ${_yamlString(server.name)}');
      buffer.writeln('  host: ${_yamlString(server.host)}');
      buffer.writeln('  user: ${_yamlString(server.user)}');
      final remark = server.remark;
      if (remark != null && remark.isNotEmpty) {
        buffer.writeln('  remark: ${_yamlString(remark)}');
      }
    }
    return buffer.toString();
  }

  String _yamlString(String value) {
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }
}
