import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/packages/certificates/certificate_parser.dart';

void main() {
  test('parses certificate line with private key and domains', () {
    final cert = parseCertificateLine(
      'example.com|1893456000|CN=R3|/fullchain.pem|/privkey.pem|example.com www.example.com',
    );

    expect(cert, isNotNull);
    expect(cert!.certName, 'example.com');
    expect(cert.privateKeyPath, '/privkey.pem');
    expect(cert.domains, ['example.com', 'www.example.com']);
    expect(cert.status, CertificateStatus.valid);
  });

  test('rejects malformed or unsafe certificate lines', () {
    expect(parseCertificateLine('bad'), isNull);
    expect(parseCertificateLine('bad name|0||/fullchain.pem'), isNull);
  });

  test('parses only certificate section from mixed output', () {
    const output = '''
ignored|0||/x
__certificates__
expired.com|1||/fullchain.pem|expired.com
__other__
example.com|1893456000||/fullchain.pem|example.com
''';

    final certs = parseCertificateList(output);

    expect(certs, hasLength(1));
    expect(certs.single.certName, 'expired.com');
    expect(certs.single.status, CertificateStatus.expired);
  });
}
