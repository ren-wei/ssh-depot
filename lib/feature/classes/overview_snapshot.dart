class OverviewSnapshot {
  const OverviewSnapshot({
    required this.distribution,
    required this.kernel,
    required this.uptime,
    required this.cpuPercent,
    required this.memoryPercent,
    required this.diskPercent,
    required this.services,
  });

  final String distribution;
  final String kernel;
  final String uptime;
  final int? cpuPercent;
  final int? memoryPercent;
  final int? diskPercent;
  final List<ServiceSnapshot> services;

  int get activeServiceCount {
    return services.where((service) => service.status == ServiceStatus.active).length;
  }
}

class ServiceSnapshot {
  const ServiceSnapshot({
    required this.name,
    required this.status,
    required this.enabled,
  });

  final String name;
  final ServiceStatus status;
  final bool? enabled;

  String get displayName => serviceDisplayName(name);
}

String serviceDisplayName(String service) {
  return service.endsWith('.service') ? service.substring(0, service.length - '.service'.length) : service;
}

enum ServiceStatus {
  active,
  inactive,
  failed,
  activating,
  deactivating,
  unknown;

  String get label {
    return switch (this) {
      ServiceStatus.active => '运行中',
      ServiceStatus.inactive => '未运行',
      ServiceStatus.failed => '失败',
      ServiceStatus.activating => '启动中',
      ServiceStatus.deactivating => '停止中',
      ServiceStatus.unknown => '未知',
    };
  }
}

class OperationRecord {
  const OperationRecord({
    required this.timestamp,
    required this.summary,
    required this.command,
    required this.exitCode,
  });

  final DateTime timestamp;
  final String summary;
  final String command;
  final int exitCode;

  bool get succeeded => exitCode == 0;
}
