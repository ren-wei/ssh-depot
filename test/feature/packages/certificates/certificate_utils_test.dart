import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/packages/certificates/certificate_utils.dart';

void main() {
  test('validates certificate names and parses unique domain lists', () {
    expect(isSafeCertificateName('example.com'), isTrue);
    expect(isSafeCertificateName('bad name'), isFalse);
    expect(parseDomainList('example.com www.example.com example.com _ *.example.com'), [
      'example.com',
      'www.example.com',
      '*.example.com',
    ]);
  });

  test('parses request domains from comma and whitespace separated input', () {
    expect(parseCertificateRequestDomains('example.com, www.example.com\nbad name'), [
      'example.com',
      'www.example.com',
      'bad',
      'name',
    ]);
    expect(parseCertificateRequestDomains(' , '), isEmpty);
  });

  test('classifies certificate expiry boundaries', () {
    expect(certificateStatus(null), CertificateStatus.unknown);
    expect(certificateStatus(DateTime.now().subtract(const Duration(days: 1))), CertificateStatus.expired);
    expect(certificateStatus(DateTime.now().add(const Duration(days: 30))), CertificateStatus.expiringSoon);
    expect(certificateStatus(DateTime.now().add(const Duration(days: 31, hours: 1))), CertificateStatus.valid);
  });

  test('matches certificate by site name or server name', () {
    const cert = NginxCertificateInfo(
      certName: 'example.com',
      status: CertificateStatus.valid,
      fullchainPath: '/fullchain.pem',
      domains: ['www.example.com'],
    );

    expect(
      matchCertificate(siteName: 'site', serverNames: ['www.example.com'], certificates: [cert]),
      same(cert),
    );
    expect(matchCertificate(siteName: 'other', serverNames: const [], certificates: [cert]), isNull);
  });
}
