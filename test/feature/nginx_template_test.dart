import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/nginx_template/template_renderer.dart';
import 'package:ssh_depot/feature/parts/nginx/utils/nginx_utils.dart';

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
}
