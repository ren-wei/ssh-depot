import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/parts/nginx/parsers/nginx_sites_parser.dart';

void main() {
  test('parses enabled available domains and matching certificates', () {
    const output = '''
__sites_available__
example.com
api.example.com
bad name
__sites_enabled__
example.com
__site_domains__
example.com|example.com www.example.com
api.example.com|api.example.com
__certificates__
example.com|1893456000|CN=R3|/fullchain.pem|/privkey.pem|www.example.com
''';

    final result = parseNginxSites(output);

    expect(result.sites.map((site) => site.name), ['api.example.com', 'example.com']);
    expect(result.sites.last.enabled, isTrue);
    expect(result.sites.last.certificate?.certName, 'example.com');
    expect(result.certificates, hasLength(1));
  });

  test('handles empty and unrelated output', () {
    final result = parseNginxSites('noise\n__unknown__\nvalue\n');

    expect(result.sites, isEmpty);
    expect(result.certificates, isEmpty);
  });

  test('infers site type from name', () {
    expect(inferNginxSiteType('api.example.com'), NginxSiteType.reverseProxy);
    expect(inferNginxSiteType('web.example.com'), NginxSiteType.custom);
  });
}
