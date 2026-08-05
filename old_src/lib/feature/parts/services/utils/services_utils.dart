import 'dart:convert';

import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

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

String searchServicesCommand() {
  return 'systemctl list-unit-files --type=service --no-pager --no-legend; '
      'systemctl list-units --type=service --all --no-pager --no-legend';
}

String serviceStatusCommand(String serviceUnit) {
  return 'status=\$(systemctl is-active ${shellQuote(serviceUnit)} 2>/dev/null || true); '
      'enabled=\$(systemctl is-enabled ${shellQuote(serviceUnit)} 2>/dev/null || true); '
      'printf "service=%s;status=%s;enabled=%s\\n" ${shellQuote(serviceUnit)} "\${status:-unknown}" "\${enabled:-unknown}"';
}

String? serviceActionCommand(String serviceUnit, String action) {
  return switch (action) {
    'start' => 'systemctl start ${shellQuote(serviceUnit)}',
    'stop' => 'systemctl stop ${shellQuote(serviceUnit)}',
    'restart' => 'systemctl restart ${shellQuote(serviceUnit)}',
    'status' => 'systemctl status ${shellQuote(serviceUnit)} --no-pager',
    _ => null,
  };
}

String serviceLogsCommand(String serviceUnit) {
  final unit = shellQuote(serviceUnit);
  if (serviceDisplayName(serviceUnit) != 'nginx') {
    return 'journalctl -u $unit --no-pager -n 80';
  }
  return 'echo "[systemd journal]"; '
      'journalctl -u $unit --no-pager -n 80; '
      'echo; echo "[nginx error.log]"; '
      'if [ -f /var/log/nginx/error.log ]; then tail -n 80 /var/log/nginx/error.log; else echo "未找到 /var/log/nginx/error.log"; fi; '
      'echo; echo "[nginx access.log]"; '
      'if [ -f /var/log/nginx/access.log ]; then tail -n 80 /var/log/nginx/access.log; else echo "未找到 /var/log/nginx/access.log"; fi';
}

List<String> parseSystemdServices(String output) {
  final services = <String>{};
  for (final line in const LineSplitter().convert(output)) {
    final columns = line.trim().split(RegExp(r'\s+'));
    if (columns.isEmpty) {
      continue;
    }
    final unit = columns.first.trim();
    if (!unit.endsWith('.service')) {
      continue;
    }
    if (isSafeServiceName(unit)) {
      services.add(unit);
    }
  }
  final sorted = services.toList()..sort();
  return sorted;
}

ServiceSnapshot? parseServiceSnapshot(String output) {
  for (final rawLine in const LineSplitter().convert(output)) {
    final line = rawLine.trim();
    if (!line.startsWith('service=')) {
      continue;
    }

    String? name;
    ServiceStatus status = ServiceStatus.unknown;
    bool? enabled;
    for (final part in line.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final key = part.substring(0, separator);
      final value = part.substring(separator + 1);
      switch (key) {
        case 'service':
          name = value;
        case 'status':
          status = switch (value) {
            'active' => ServiceStatus.active,
            'inactive' => ServiceStatus.inactive,
            'failed' => ServiceStatus.failed,
            _ => ServiceStatus.unknown,
          };
        case 'enabled':
          enabled = switch (value) {
            'enabled' => true,
            'disabled' => false,
            _ => null,
          };
      }
    }
    if (name != null && name.isNotEmpty) {
      return ServiceSnapshot(name: name, status: status, enabled: enabled);
    }
  }
  return null;
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
