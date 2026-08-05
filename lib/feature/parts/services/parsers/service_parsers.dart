import 'dart:convert';

import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/parts/services/commands/service_commands.dart';

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
            'activating' => ServiceStatus.activating,
            'deactivating' => ServiceStatus.deactivating,
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
