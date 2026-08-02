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
}

class NginxCertificateInfo {
  const NginxCertificateInfo({
    required this.domain,
    required this.status,
    required this.fullchainPath,
    this.names = const [],
    this.expiresAt,
    this.issuer,
  });

  final String domain;
  final CertificateStatus status;
  final String fullchainPath;
  final List<String> names;
  final DateTime? expiresAt;
  final String? issuer;

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

class RemoteCommandResult {
  const RemoteCommandResult({
    required this.exitCode,
    required this.output,
  });

  final int exitCode;
  final String output;

  bool get succeeded => exitCode == 0;
}
