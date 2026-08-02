import 'dart:io';

import 'package:yaml/yaml.dart';

import 'config_paths.dart';

class ServicePreferencesStore {
  const ServicePreferencesStore({required ConfigPaths paths}) : _paths = paths;

  final ConfigPaths _paths;

  Future<List<String>> load() async {
    final file = File(_paths.preferencesFile);
    if (!await file.exists()) {
      return const ['nginx'];
    }

    final parsed = loadYaml(await file.readAsString());
    if (parsed is! YamlMap) {
      return const ['nginx'];
    }

    final services = parsed['services'];
    if (services is! YamlList) {
      return const ['nginx'];
    }

    final values = [
      for (final service in services) service.toString().trim(),
    ].where((service) => service.isNotEmpty).toSet().toList();

    return values.isEmpty ? const ['nginx'] : values;
  }

  Future<void> save(List<String> services) async {
    final file = File(_paths.preferencesFile);
    await file.parent.create(recursive: true);
    await file.writeAsString(_encodeServices(services));
  }

  String _encodeServices(List<String> services) {
    final buffer = StringBuffer('services:\n');
    for (final service in services) {
      buffer.writeln('  - ${_yamlString(service)}');
    }
    return buffer.toString();
  }

  String _yamlString(String value) {
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }
}
