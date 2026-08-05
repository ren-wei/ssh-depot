import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/nginx_site.dart';

void main() {
  test('returns site status type and missing certificate labels', () {
    const site = NginxSite(
      name: 'example.com',
      enabled: true,
      availablePath: '/etc/nginx/sites-available/example.com',
      configType: NginxSiteType.reverseProxy,
    );

    expect(site.statusLabel, '已启用');
    expect(site.typeLabel, '反向代理');
    expect(site.certificateStatus, CertificateStatus.missing);
  });

  test('certificate uses first domain and maps all status labels', () {
    const cert = NginxCertificateInfo(
      certName: 'example.com',
      status: CertificateStatus.expiringSoon,
      fullchainPath: '/fullchain.pem',
      domains: ['www.example.com', 'example.com'],
    );

    expect(cert.domain, 'www.example.com');
    expect(cert.names, ['www.example.com', 'example.com']);
    expect(cert.statusLabel, '即将过期');
    expect(
      CertificateStatus.values
          .map(
            (status) => NginxCertificateInfo(certName: 'c', status: status, fullchainPath: '/f').statusLabel,
          )
          .toList(),
      ['有效', '即将过期', '已过期', '未配置', '未知'],
    );
  });
}
