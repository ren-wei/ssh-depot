import 'dart:io';

import 'package:yaml/yaml.dart';

import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';

class ServicePreferencesStore {
  const ServicePreferencesStore({required ConfigPaths paths}) : _paths = paths;

  final ConfigPaths _paths;

  Future<List<String>> load(String target) async {
    final file = File(_paths.preferencesFile);
    if (!await file.exists()) {
      return const ['nginx.service'];
    }

    final parsed = loadYaml(await file.readAsString());
    if (parsed is! YamlMap) {
      return const ['nginx.service'];
    }

    final servicesByTarget = parsed['servicesByTarget'];
    if (servicesByTarget is YamlMap) {
      return _parseServices(servicesByTarget[target]);
    }

    return _parseServices(parsed['services']);
  }

  Future<void> save(String target, List<String> services) async {
    final file = File(_paths.preferencesFile);
    await file.parent.create(recursive: true);
    final existing = await _loadAll();
    existing[target] = _normalizedOrDefault(services);
    await file.writeAsString(_encodeServicesByTarget(existing));
  }

  Future<Map<String, List<String>>> _loadAll() async {
    final file = File(_paths.preferencesFile);
    if (!await file.exists()) {
      return {};
    }

    final parsed = loadYaml(await file.readAsString());
    if (parsed is! YamlMap) {
      return {};
    }

    final servicesByTarget = parsed['servicesByTarget'];
    if (servicesByTarget is YamlMap) {
      return {
        for (final entry in servicesByTarget.entries) entry.key.toString(): _parseServices(entry.value),
      };
    }

    final legacyServices = _parseServices(parsed['services']);
    return legacyServices.isEmpty ? {} : {'default': legacyServices};
  }

  List<String> _parseServices(Object? services) {
    if (services is! YamlList) {
      return const ['nginx.service'];
    }

    final values = _normalizeServices([
      for (final service in services) service.toString(),
    ]);

    return values.isEmpty ? const ['nginx.service'] : values;
  }

  List<String> _normalizeServices(List<String> services) {
    return [
      for (final service in services) service.trim(),
    ].where((service) => service.isNotEmpty).toSet().toList(growable: false);
  }

  List<String> _normalizedOrDefault(List<String> services) {
    final values = _normalizeServices(services);
    return values.isEmpty ? const ['nginx.service'] : values;
  }

  String _encodeServicesByTarget(Map<String, List<String>> servicesByTarget) {
    final buffer = StringBuffer('servicesByTarget:\n');
    final targets = servicesByTarget.keys.toList()..sort();
    for (final target in targets) {
      buffer.writeln('  ${_yamlString(target)}:');
      for (final service in servicesByTarget[target] ?? const <String>[]) {
        buffer.writeln('    - ${_yamlString(service)}');
      }
    }
    return buffer.toString();
  }

  String _yamlString(String value) {
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  }
}
