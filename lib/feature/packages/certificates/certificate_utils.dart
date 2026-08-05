import 'package:ssh_depot/feature/classes/nginx_site.dart';

bool isSafeCertificateName(String value) {
  return RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*$').hasMatch(value);
}

List<String> parseDomainList(String value) {
  return value
      .split(RegExp(r'\s+'))
      .map((domain) => domain.trim())
      .where(
        (domain) =>
            domain.isNotEmpty &&
            domain != '_' &&
            isSafeCertificateName(domain.replaceFirst(RegExp(r'^\*\.'), 'wildcard.')),
      )
      .toSet()
      .toList();
}

List<String> parseCertificateRequestDomains(String value) {
  return value
      .split(RegExp(r'[\s,]+'))
      .map((domain) => domain.trim())
      .where((domain) => domain.isNotEmpty && isSafeCertificateName(domain.replaceFirst(RegExp(r'^\*\.'), 'wildcard.')))
      .toSet()
      .toList();
}

CertificateStatus certificateStatus(DateTime? expiresAt) {
  if (expiresAt == null) {
    return CertificateStatus.unknown;
  }
  final now = DateTime.now();
  if (expiresAt.isBefore(now)) {
    return CertificateStatus.expired;
  }
  if (expiresAt.difference(now).inDays <= 30) {
    return CertificateStatus.expiringSoon;
  }
  return CertificateStatus.valid;
}

NginxCertificateInfo? matchCertificate({
  required String siteName,
  required List<String> serverNames,
  required List<NginxCertificateInfo> certificates,
}) {
  final candidates = {
    siteName,
    ...serverNames,
  };
  for (final certificate in certificates) {
    final certificateNames = {
      certificate.certName,
      ...certificate.domains,
    };
    if (candidates.any(certificateNames.contains)) {
      return certificate;
    }
  }
  return null;
}
