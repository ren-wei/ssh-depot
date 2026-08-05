import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/parts/nginx/templates/built_in_templates.dart';
import 'package:ssh_depot/feature/parts/nginx/templates/nginx_site_templates.dart';
import 'package:ssh_depot/feature/parts/nginx/templates/template_manifest.dart';
import 'package:ssh_depot/feature/parts/nginx/templates/template_renderer.dart';

void main() {
  test('renders reverse proxy template', () {
    final config = const TemplateRenderer().render(template: reverseProxyTemplate, variables: {
      'domain': 'example.com',
      'upstream_host': '127.0.0.1',
      'upstream_port': 3000,
    });

    expect(config, contains('server_name example.com;'));
    expect(config, contains('proxy_pass http://127.0.0.1:3000;'));
  });

  test('renders null variables as empty and leaves unknown placeholders intact', () {
    final config = const TemplateRenderer().render(
      template: 'server_name {{domain}}; root {{root_path}};',
      variables: const {'domain': null},
    );

    expect(config, 'server_name ; root {{root_path}};');
  });

  test('declares built in template manifests', () {
    expect(builtInNginxTemplates.map((template) => template.id), ['static_site', 'reverse_proxy']);
    expect(builtInNginxTemplates.first.variables.first.label, '域名');
    expect(builtInNginxTemplates.first.variables.last.type, TemplateVariableType.boolean);
  });
}
