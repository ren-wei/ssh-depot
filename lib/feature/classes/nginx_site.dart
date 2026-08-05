class NginxSite {
  const NginxSite({
    required this.name,
    required this.enabled,
    required this.availablePath,
    this.configType = NginxSiteType.unknown,
    this.serverNames = const [],
    this.certificate,
  });

  final String name;
  final bool enabled;
  final String availablePath;
  final NginxSiteType configType;
  final List<String> serverNames;
  final NginxCertificateInfo? certificate;

  String get statusLabel => enabled ? '已启用' : '未启用';

  String get typeLabel {
    return switch (configType) {
      NginxSiteType.staticSite => '静态站点',
      NginxSiteType.reverseProxy => '反向代理',
      NginxSiteType.custom => '自定义',
      NginxSiteType.unknown => '未知',
    };
  }

  CertificateStatus get certificateStatus {
    return certificate?.status ?? CertificateStatus.missing;
  }
}

class NginxCertificateInfo {
  const NginxCertificateInfo({
    required this.certName,
    required this.status,
    required this.fullchainPath,
    this.privateKeyPath,
    this.domains = const [],
    this.expiresAt,
    this.issuer,
  });

  final String certName;
  final CertificateStatus status;
  final String fullchainPath;
  final String? privateKeyPath;
  final List<String> domains;
  final DateTime? expiresAt;
  final String? issuer;

  String get domain => domains.isEmpty ? certName : domains.first;
  List<String> get names => domains;

  String get statusLabel {
    return switch (status) {
      CertificateStatus.valid => '有效',
      CertificateStatus.expiringSoon => '即将过期',
      CertificateStatus.expired => '已过期',
      CertificateStatus.missing => '未配置',
      CertificateStatus.unknown => '未知',
    };
  }
}

enum CertificateStatus {
  valid,
  expiringSoon,
  expired,
  missing,
  unknown,
}

enum NginxSiteType {
  staticSite,
  reverseProxy,
  custom,
  unknown,
}
