import '../../classes/overview_snapshot.dart';

class OverviewParser {
  const OverviewParser();

  OverviewSnapshot parse(String output) {
    final values = <String, String>{};
    final services = <ServiceSnapshot>[];

    for (final rawLine in output.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('service=')) {
        final service = _parseService(line);
        if (service != null) {
          services.add(service);
        }
        continue;
      }

      final separator = line.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      values[line.substring(0, separator)] = line.substring(separator + 1);
    }

    return OverviewSnapshot(
      distribution: values['distribution'] ?? '--',
      kernel: values['kernel'] ?? '--',
      uptime: values['uptime'] ?? '--',
      cpuPercent: _parsePercent(values['cpu']),
      memoryPercent: _parsePercent(values['memory']),
      diskPercent: _parsePercent(values['disk']),
      services: services,
    );
  }

  ServiceSnapshot? _parseService(String line) {
    final parts = line.split(';');
    String? name;
    ServiceStatus status = ServiceStatus.unknown;
    bool? enabled;

    for (final part in parts) {
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
          status = _parseStatus(value);
        case 'enabled':
          enabled = switch (value) {
            'enabled' => true,
            'disabled' => false,
            _ => null,
          };
      }
    }

    if (name == null || name.isEmpty) {
      return null;
    }
    return ServiceSnapshot(name: name, status: status, enabled: enabled);
  }

  ServiceStatus _parseStatus(String value) {
    return switch (value) {
      'active' => ServiceStatus.active,
      'inactive' => ServiceStatus.inactive,
      'failed' => ServiceStatus.failed,
      _ => ServiceStatus.unknown,
    };
  }

  int? _parsePercent(String? value) {
    if (value == null) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return null;
    }
    return parsed.round().clamp(0, 100);
  }
}
