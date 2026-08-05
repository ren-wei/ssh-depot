import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/nginx_template_definition.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/parts/nginx/stores/nginx_templates_store.dart';

void main() {
  test('loads empty list when templates directory is missing', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_nginx_templates_store_');
    addTearDown(() => tempDir.delete(recursive: true));

    expect(await NginxTemplatesStore(paths: ConfigPaths(homeDirectory: tempDir.path)).load(), isEmpty);
  });

  test('saves loads filters invalid files and sorts templates by name', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_nginx_templates_store_');
    addTearDown(() => tempDir.delete(recursive: true));
    final paths = ConfigPaths(homeDirectory: tempDir.path);
    final store = NginxTemplatesStore(paths: paths);

    await store
        .save(const NginxTemplateDefinition(id: 'b template', name: 'B', type: '自定义', content: 'server_name b;'));
    await store.save(const NginxTemplateDefinition(id: 'a', name: 'A', type: '静态', content: 'server_name a;'));
    await File('${paths.templatesDirectory}/invalid.yaml').writeAsString('id: invalid\nname: invalid\n');
    await File('${paths.templatesDirectory}/ignored.txt').writeAsString('ignored');

    final templates = await store.load();

    expect(templates.map((template) => template.name), ['A', 'B']);
    expect(await File('${paths.templatesDirectory}/b_template.yaml').exists(), isTrue);
  });

  test('escapes yaml fields while saving template metadata', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_nginx_templates_store_');
    addTearDown(() => tempDir.delete(recursive: true));
    final paths = ConfigPaths(homeDirectory: tempDir.path);

    await NginxTemplatesStore(paths: paths).save(
      const NginxTemplateDefinition(
        id: 'quote',
        name: 'A "B"',
        type: '自定义',
        description: 'desc',
        content: 'line1\nline2',
      ),
    );

    final raw = await File('${paths.templatesDirectory}/quote.yaml').readAsString();
    expect(raw, contains(r'name: "A \"B\""'));
    expect(raw, contains('  line1\n  line2'));
  });
}
