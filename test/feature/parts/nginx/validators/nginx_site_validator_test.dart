import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/parts/nginx/validators/nginx_site_validator.dart';

void main() {
  test('validates safe nginx site names', () {
    expect(isSafeSiteName('example.com'), isTrue);
    expect(isSafeSiteName('api_v1.conf'), isTrue);
    expect(isSafeSiteName('bad name'), isFalse);
    expect(isSafeSiteName('-bad'), isFalse);
    expect(isSafeSiteName(''), isFalse);
  });
}
