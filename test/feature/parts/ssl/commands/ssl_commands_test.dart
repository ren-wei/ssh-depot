import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/parts/ssl/commands/ssl_commands.dart';
import 'package:ssh_depot/feature/parts/ssl/parsers/ssl_parsers.dart';

void main() {
  test('builds nginx certbot command when automatic config is requested', () {
    final command = requestCertificateCommand(
      domains: const ['example.com', 'www.example.com'],
      email: 'ops@example.com',
      useWebroot: false,
      webroot: '',
    );

    expect(command.text, contains('certbot --nginx'));
    expect(command.text, contains("-d 'example.com'"));
    expect(command.text, contains("-m 'ops@example.com'"));
  });

  test('builds webroot certbot command when config mutation is disabled', () {
    final command = updateCertificateDomainsCommand(
      certName: 'example.com',
      domains: const ['example.com'],
      useWebroot: true,
      webroot: '/var/www/html',
    );

    expect(command.text, contains('certonly --webroot'));
    expect(command.text, contains("--cert-name 'example.com'"));
    expect(command.text, contains("-w '/var/www/html'"));
  });

  test('builds certificate details environment renew and delete commands', () {
    expect(
        certificateDetailsCommand('example.com').text, contains('/etc/letsencrypt/live/\'example.com\'/fullchain.pem'));
    expect(certificateEnvironmentCommand().text, contains('[certbot plugins]'));
    expect(
        renewCertificateCommand('example.com', dryRun: true).text, "certbot renew --cert-name 'example.com' --dry-run");
    expect(renewCertificateCommand('example.com').summary, '续期证书');
    expect(deleteCertificateCommand('example.com').text, "certbot delete --cert-name 'example.com' --non-interactive");
  });

  test('builds nginx based domain update command', () {
    final command = updateCertificateDomainsCommand(
      certName: 'example.com',
      domains: const ['example.com', 'www.example.com'],
      useWebroot: false,
      webroot: '',
    );

    expect(command.text, contains('certbot --nginx'));
    expect(command.text, contains("--cert-name 'example.com'"));
    expect(command.text, contains("-d 'www.example.com'"));
  });

  test('parses certificate list output', () {
    const output = '''
__certificates__
example.com|1893456000|CN=R3|/etc/letsencrypt/live/example.com/fullchain.pem|/etc/letsencrypt/live/example.com/privkey.pem|example.com www.example.com
''';

    final certs = parseCertificates(output);

    expect(certs, hasLength(1));
    expect(certs.single.certName, 'example.com');
    expect(certs.single.status, CertificateStatus.valid);
    expect(certs.single.domains, ['example.com', 'www.example.com']);
  });

  test('returns empty certificate list for empty output', () {
    expect(parseCertificates(''), isEmpty);
  });
}
