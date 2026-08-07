import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/commands/echo_command.dart';
import 'package:ssh_depot/feature/packages/commands/journalctl_command.dart';
import 'package:ssh_depot/feature/packages/commands/systemctl_command.dart';
import 'package:ssh_depot/feature/parts/services/parsers/service_parsers.dart';

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
  return CommandSequence(
    summary: '搜索服务',
    commands: [SystemctlCommand.listServices()],
    parser: (result) {
      if (!result.succeeded) {
        return const [];
      }
      return parseSystemdServices(result.output);
    },
  );
}

Command serviceStatusCommand(String serviceUnit) {
  return CommandSequence(
    summary: '获取 ${serviceDisplayName(serviceUnit)} 状态',
    commands: [SystemctlCommand.serviceSnapshot(serviceUnit)],
    parser: (result) {
      if (!result.succeeded) {
        return null;
      }
      return parseServiceSnapshot(result.output);
    },
  );
}

Command? serviceActionCommand(String serviceUnit, String action) {
  final summary = '${serviceDisplayName(serviceUnit)} ${serviceActionSummary(action)}';
  if (!const {'start', 'stop', 'restart', 'status'}.contains(action)) {
    return null;
  }
  return SystemctlCommand.serviceAction(
    unit: serviceUnit,
    action: action,
    summary: summary,
  );
}

Command serviceLogsCommand(String serviceUnit) {
  final summary = '查看 ${serviceDisplayName(serviceUnit)} 日志';
  if (serviceDisplayName(serviceUnit) != 'nginx') {
    return CommandSequence(
      summary: summary,
      commands: [JournalctlCommand.unit(serviceUnit)],
      parser: (result) => result,
    );
  }
  return NginxServiceLogsCommand(serviceUnit, summary: summary);
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

class NginxServiceLogsCommand extends Command {
  const NginxServiceLogsCommand(this.serviceUnit, {required this.summary});

  final String serviceUnit;

  @override
  final String summary;

  @override
  String get text {
    return '${EchoCommand('[systemd journal]').text}; '
        '${JournalctlCommand.unit(serviceUnit).text}; '
        'echo; ${EchoCommand('[nginx error.log]').text}; '
        'if [ -f /var/log/nginx/error.log ]; then tail -n 80 /var/log/nginx/error.log; else ${EchoCommand('未找到 /var/log/nginx/error.log').text}; fi; '
        'echo; ${EchoCommand('[nginx access.log]').text}; '
        'if [ -f /var/log/nginx/access.log ]; then tail -n 80 /var/log/nginx/access.log; else ${EchoCommand('未找到 /var/log/nginx/access.log').text}; fi';
  }

  @override
  RemoteCommandResult parse(RemoteCommandResult result) => result;
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
