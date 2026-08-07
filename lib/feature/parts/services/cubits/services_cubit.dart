import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/packages/command_runner/command_runner.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/packages/local_config/service_preferences_store.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';
import 'package:ssh_depot/feature/parts/services/commands/service_commands.dart';
import 'package:ssh_depot/feature/parts/services/parsers/service_parsers.dart';
import 'package:ssh_depot/feature/utils/home_directory.dart';

class ServicesCubit extends ChangeNotifier {
  ServicesCubit({
    required CommandRunner commandRunner,
    required SshTarget? Function() currentTarget,
    ServicePreferencesStore? servicePreferencesStore,
  })  : _commandRunner = commandRunner,
        _currentTarget = currentTarget,
        _servicePreferencesStore = servicePreferencesStore ??
            ServicePreferencesStore(
              paths: ConfigPaths(homeDirectory: resolveHomeDirectory()),
            );

  final CommandRunner _commandRunner;
  final SshTarget? Function() _currentTarget;
  final ServicePreferencesStore _servicePreferencesStore;

  List<String> managedServices = const ['nginx.service'];
  Map<String, ServiceSnapshot> serviceSnapshots = const {};
  String? serviceLogsService;
  String serviceLogsOutput = '';

  Future<void> loadForTarget(SshTarget? target) async {
    if (target == null) {
      managedServices = const ['nginx.service'];
      clearRuntime();
      notifyListeners();
      return;
    }
    managedServices = normalizeManagedServices(await _servicePreferencesStore.load(target.address));
    serviceSnapshots = const {};
    serviceLogsService = null;
    serviceLogsOutput = '';
    notifyListeners();
  }

  Future<void> addManagedService(String service) async {
    final cleanService = serviceUnitName(service);
    if (!isSafeServiceName(cleanService)) {
      _commandRunner.setStatus('无效服务名');
      return;
    }
    if (managedServices.contains(cleanService)) {
      _commandRunner.setStatus('服务已存在');
      return;
    }

    managedServices = [...managedServices, cleanService];
    await _saveManagedServices();
    _commandRunner.setStatus('✓ 已添加服务 ${serviceDisplayName(cleanService)}');
    await refreshServiceStatus(cleanService);
  }

  Future<void> removeManagedService(String service) async {
    managedServices = [
      for (final item in managedServices)
        if (item != service) item,
    ];
    if (managedServices.isEmpty) {
      managedServices = const ['nginx.service'];
    }
    serviceSnapshots = {
      for (final entry in serviceSnapshots.entries)
        if (managedServices.contains(entry.key)) entry.key: entry.value,
    };
    await _saveManagedServices();
    _commandRunner.setStatus('✓ 已移除服务 ${serviceDisplayName(service)}');
    notifyListeners();
  }

  Future<List<String>> searchRemoteServices() async {
    final result = await _commandRunner.runCaptureCommand(
      command: searchServicesCommand(),
      timeout: const Duration(seconds: 20),
    );
    if (result == null || !result.succeeded) {
      return const [];
    }
    return parseSystemdServices(result.output);
  }

  Future<void> refreshServiceStatus(String service) async {
    final serviceUnit = serviceUnitName(service);
    if (!isSafeServiceName(serviceUnit)) {
      _commandRunner.setStatus('无效服务名');
      return;
    }

    final result = await _commandRunner.runCaptureCommand(
      command: CommandWithSummary(
        command: serviceStatusCommand(serviceUnit),
        summary: '获取 ${serviceDisplayName(serviceUnit)} 状态',
      ),
      timeout: const Duration(seconds: 12),
    );

    if (result == null || !result.succeeded) {
      return;
    }
    final snapshot = parseServiceSnapshot(result.output);
    if (snapshot == null) {
      return;
    }
    serviceSnapshots = {...serviceSnapshots, snapshot.name: snapshot};
    notifyListeners();
  }

  Future<void> refreshManagedServiceStatuses() async {
    for (final service in managedServices) {
      await refreshServiceStatus(service);
    }
  }

  Future<void> serviceAction(String service, String action) async {
    final serviceUnit = serviceUnitName(service);
    if (!isSafeServiceName(serviceUnit)) {
      _commandRunner.setStatus('无效服务名');
      return;
    }
    if (action == 'logs') {
      await fetchServiceLogs(serviceUnit);
      return;
    }
    final command = serviceActionCommand(serviceUnit, action);
    if (command == null) {
      _commandRunner.setStatus('未知服务操作');
      return;
    }
    final result = await _commandRunner.runCaptureCommand(
      command: CommandWithSummary(
        command: command,
        summary: '${serviceDisplayName(serviceUnit)} ${serviceActionSummary(action)}',
      ),
    );
    if (action == 'start' || action == 'stop' || action == 'restart') {
      if (result?.succeeded == true) {
        final snapshot = expectedServiceStatus(
          serviceUnit: serviceUnit,
          action: action,
          previous: serviceSnapshots[serviceUnit],
        );
        serviceSnapshots = {...serviceSnapshots, serviceUnit: snapshot};
        notifyListeners();
      }
      await refreshServiceStatus(serviceUnit);
      await fetchServiceLogs(serviceUnit);
    }
  }

  Future<void> fetchServiceLogs(String service) async {
    final serviceUnit = serviceUnitName(service);
    if (!isSafeServiceName(serviceUnit)) {
      _commandRunner.setStatus('无效服务名');
      return;
    }
    serviceLogsService = serviceUnit;
    serviceLogsOutput = '';
    notifyListeners();

    final result = await _commandRunner.runCaptureCommand(
      command: CommandWithSummary(
        command: serviceLogsCommand(serviceUnit),
        summary: '查看 ${serviceDisplayName(serviceUnit)} 日志',
      ),
    );

    if (result == null) {
      serviceLogsOutput = '查看日志失败';
    } else if (result.output.isEmpty) {
      serviceLogsOutput = result.succeeded ? '暂无日志输出' : '查看日志失败';
    } else {
      serviceLogsOutput = result.output;
    }
    notifyListeners();
  }

  void clearRuntime() {
    serviceSnapshots = const {};
    serviceLogsService = null;
    serviceLogsOutput = '';
  }

  Future<void> _saveManagedServices() async {
    final target = _currentTarget();
    if (target == null) {
      notifyListeners();
      return;
    }
    try {
      await _servicePreferencesStore.save(target.address, managedServices);
    } catch (error) {
      _commandRunner.setStatus('✗ 保存服务列表失败: $error');
    }
    notifyListeners();
  }
}
