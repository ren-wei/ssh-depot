import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/nginx_template_definition.dart';

void main() {
  test('stores template metadata', () {
    const template = NginxTemplateDefinition(
      id: 'reverse-proxy',
      name: '反向代理',
      type: 'proxy',
      content: 'server {}',
      description: 'desc',
      builtIn: true,
    );

    expect(template.id, 'reverse-proxy');
    expect(template.description, 'desc');
    expect(template.builtIn, isTrue);
  });
}
