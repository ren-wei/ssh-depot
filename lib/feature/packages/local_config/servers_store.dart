import 'dart:io';

import 'package:yaml/yaml.dart';

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
    ].where((server) => server.host.isNotEmpty).toList();
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
      if ((server.remark ?? '').isNotEmpty) {
        buffer.writeln('  remark: ${_yamlString(server.remark!)}');
      }
    }
    return buffer.toString();
  }

  String _yamlString(String value) {
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }
}
