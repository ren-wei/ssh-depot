import 'dart:io';

import 'package:yaml/yaml.dart';

import 'package:ssh_depot/feature/classes/nginx_template_definition.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';

class NginxTemplatesStore {
  const NginxTemplatesStore({required ConfigPaths paths}) : _paths = paths;

  final ConfigPaths _paths;

  Future<List<NginxTemplateDefinition>> load() async {
    final directory = Directory(_paths.templatesDirectory);
    if (!await directory.exists()) {
      return const [];
    }

    final templates = <NginxTemplateDefinition>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.yaml')) {
        continue;
      }
      final parsed = loadYaml(await entity.readAsString());
      if (parsed is! YamlMap) {
        continue;
      }
      final id = parsed['id']?.toString() ?? '';
      final name = parsed['name']?.toString() ?? '';
      final content = parsed['content']?.toString() ?? '';
      if (id.isEmpty || name.isEmpty || content.isEmpty) {
        continue;
      }
      templates.add(
        NginxTemplateDefinition(
          id: id,
          name: name,
          type: parsed['type']?.toString() ?? '自定义',
          description: parsed['description']?.toString(),
          content: content,
        ),
      );
    }
    templates.sort((a, b) => a.name.compareTo(b.name));
    return templates;
  }

  Future<void> save(NginxTemplateDefinition template) async {
    final directory = Directory(_paths.templatesDirectory);
    await directory.create(recursive: true);
    final file = File('${directory.path}/${_safeFileName(template.id)}.yaml');
    await file.writeAsString(_encode(template));
  }

  String _encode(NginxTemplateDefinition template) {
    return '''
id: ${_yamlString(template.id)}
name: ${_yamlString(template.name)}
type: ${_yamlString(template.type)}
description: ${_yamlString(template.description ?? '')}
content: |
${_indent(template.content)}
''';
  }

  String _indent(String value) {
    return value.split('\n').map((line) => '  $line').join('\n');
  }

  String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]+'), '_');
  }

  String _yamlString(String value) {
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }
}
