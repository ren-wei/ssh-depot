import 'dart:convert';

import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/packages/certificates/certificate_utils.dart';

NginxCertificateInfo? parseCertificateLine(String line) {
  final parts = line.split('|');
  if (parts.length < 4 || !isSafeCertificateName(parts[0])) {
    return null;
  }
  final epoch = int.tryParse(parts[1]);
  final expiresAt = epoch == null || epoch <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
  final domains = parseDomainList(parts.length > 5 ? parts[5] : (parts.length > 4 ? parts[4] : ''));
  return NginxCertificateInfo(
    certName: parts[0],
    expiresAt: expiresAt,
    issuer: parts[2].isEmpty ? null : parts[2],
    fullchainPath: parts[3],
    privateKeyPath: parts.length > 5 && parts[4].isNotEmpty ? parts[4] : null,
    domains: domains,
    status: certificateStatus(expiresAt),
  );
}

List<NginxCertificateInfo> parseCertificateList(String output) {
  final certificates = <NginxCertificateInfo>[];
  var inCertificateSection = false;
  for (final rawLine in const LineSplitter().convert(output)) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    if (line == '__certificates__') {
      inCertificateSection = true;
      continue;
    }
    if (line.startsWith('__') && line.endsWith('__')) {
      inCertificateSection = false;
      continue;
    }
    if (!inCertificateSection) {
      continue;
    }
    final certificate = parseCertificateLine(line);
    if (certificate != null) {
      certificates.add(certificate);
    }
  }
  return certificates;
}
