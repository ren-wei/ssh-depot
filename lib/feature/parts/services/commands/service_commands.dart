import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/commands/echo_command.dart';
import 'package:ssh_depot/feature/packages/commands/journalctl_command.dart';
import 'package:ssh_depot/feature/packages/commands/systemctl_command.dart';

bool isSafeServiceName(String value) {
  return RegExp(r'^[a-zA-Z0-9_.@:-]+$').hasMatch(value);
}

String serviceUnitName(String service) {
  final cleanService = service.trim();
  if (cleanService.isEmpty || cleanService.endsWith('.service')) {
    return cleanService;
  }
  return '$cleanService.service';
}

List<String> normalizeManagedServices(List<String> services) {
  final normalized = [
    for (final service in services) serviceUnitName(service),
  ].where(isSafeServiceName).toSet().toList();
  return normalized.isEmpty ? const ['nginx.service'] : normalized;
}

Command searchServicesCommand() {
  return SystemctlCommand.listServices();
}

Command serviceStatusCommand(String serviceUnit) {
  return SystemctlCommand.serviceSnapshot(serviceUnit);
}

Command? serviceActionCommand(String serviceUnit, String action) {
  return switch (action) {
    'start' => CommandWithSummary(
        command: SystemctlCommand.start(serviceUnit),
        summary: serviceActionSummary(action),
      ),
    'stop' => CommandWithSummary(
        command: SystemctlCommand.stop(serviceUnit),
        summary: serviceActionSummary(action),
      ),
    'restart' => CommandWithSummary(
        command: SystemctlCommand.restart(serviceUnit),
        summary: serviceActionSummary(action),
      ),
    'status' => CommandWithSummary(
        command: SystemctlCommand.status(serviceUnit),
        summary: serviceActionSummary(action),
      ),
    _ => null,
  };
}

Command serviceLogsCommand(String serviceUnit) {
  if (serviceDisplayName(serviceUnit) != 'nginx') {
    return JournalctlCommand.unit(serviceUnit);
  }
  return NginxServiceLogsCommand(serviceUnit);
}

String serviceActionSummary(String action) {
  return switch (action) {
    'start' => '启动服务',
    'stop' => '停止服务',
    'restart' => '重启服务',
    'status' => '查看服务状态',
    _ => '服务操作',
  };
}

class NginxServiceLogsCommand implements Command {
  const NginxServiceLogsCommand(this.serviceUnit);

  final String serviceUnit;

  @override
  String get summary => '查看服务日志';

  @override
  String get text {
    return '${EchoCommand('[systemd journal]').text}; '
        '${JournalctlCommand.unit(serviceUnit).text}; '
        'echo; ${EchoCommand('[nginx error.log]').text}; '
        'if [ -f /var/log/nginx/error.log ]; then tail -n 80 /var/log/nginx/error.log; else ${EchoCommand('未找到 /var/log/nginx/error.log').text}; fi; '
        'echo; ${EchoCommand('[nginx access.log]').text}; '
        'if [ -f /var/log/nginx/access.log ]; then tail -n 80 /var/log/nginx/access.log; else ${EchoCommand('未找到 /var/log/nginx/access.log').text}; fi';
  }
}

ServiceSnapshot expectedServiceStatus({
  required String serviceUnit,
  required String action,
  ServiceSnapshot? previous,
}) {
  final status = switch (action) {
    'stop' => ServiceStatus.inactive,
    'start' || 'restart' => ServiceStatus.active,
    _ => previous?.status ?? ServiceStatus.unknown,
  };
  return ServiceSnapshot(
    name: serviceUnit,
    status: status,
    enabled: previous?.enabled,
  );
}
