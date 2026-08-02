class NginxSite {
  const NginxSite({
    required this.name,
    required this.enabled,
    required this.availablePath,
    this.configType = NginxSiteType.unknown,
  });

  final String name;
  final bool enabled;
  final String availablePath;
  final NginxSiteType configType;

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
