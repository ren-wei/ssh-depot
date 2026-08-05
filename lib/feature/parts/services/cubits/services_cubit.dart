import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/packages/local_config/service_preferences_store.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';
import 'package:ssh_depot/feature/utils/home_directory.dart';

import '../utils/services_utils.dart';

class ServicesCubit extends ChangeNotifier {
  ServicesCubit({
    required CommandRunnerCubit commandRunnerCubit,
    required SshTarget? Function() currentTarget,
  })  : _commandRunnerCubit = commandRunnerCubit,
        _currentTarget = currentTarget,
        _servicePreferencesStore = ServicePreferencesStore(
          paths: ConfigPaths(homeDirectory: resolveHomeDirectory()),
        );

  final CommandRunnerCubit _commandRunnerCubit;
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
      _commandRunnerCubit.setStatus('无效服务名');
      return;
    }
    if (managedServices.contains(cleanService)) {
      _commandRunnerCubit.setStatus('服务已存在');
      return;
    }

    managedServices = [...managedServices, cleanService];
    await _saveManagedServices();
    _commandRunnerCubit.setStatus('✓ 已添加服务 ${serviceDisplayName(cleanService)}');
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
    _commandRunnerCubit.setStatus('✓ 已移除服务 ${serviceDisplayName(service)}');
    notifyListeners();
  }

  Future<List<String>> searchRemoteServices() async {
    final output = StringBuffer();
    final exitCode = await _commandRunnerCubit.runCaptureRemote(
      summary: '搜索服务',
      command: searchServicesCommand(),
      timeout: const Duration(seconds: 20),
    );
    if (exitCode == null || !exitCode.succeeded) {
      return const [];
    }
    output.write(exitCode.output);
    return parseSystemdServices(output.toString());
  }

  Future<void> refreshServiceStatus(String service) async {
    final serviceUnit = serviceUnitName(service);
    if (!isSafeServiceName(serviceUnit)) {
      _commandRunnerCubit.setStatus('无效服务名');
      return;
    }

    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: '获取 ${serviceDisplayName(serviceUnit)} 状态',
      command: serviceStatusCommand(serviceUnit),
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

  Future<void> serviceAction(String service, String action) async {
    final serviceUnit = serviceUnitName(service);
    if (!isSafeServiceName(serviceUnit)) {
      _commandRunnerCubit.setStatus('无效服务名');
      return;
    }
    if (action == 'logs') {
      await fetchServiceLogs(serviceUnit);
      return;
    }
    final command = serviceActionCommand(serviceUnit, action);
    if (command == null) {
      _commandRunnerCubit.setStatus('未知服务操作');
      return;
    }
    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: '${serviceDisplayName(serviceUnit)} $action',
      command: command,
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
      _commandRunnerCubit.setStatus('无效服务名');
      return;
    }
    serviceLogsService = serviceUnit;
    serviceLogsOutput = '';
    notifyListeners();

    final output = StringBuffer();
    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: '查看 ${serviceDisplayName(serviceUnit)} 日志',
      command: serviceLogsCommand(serviceUnit),
    );

    if (result == null) {
      serviceLogsOutput = '查看日志失败';
    } else if (result.output.isEmpty) {
      serviceLogsOutput = result.succeeded ? '暂无日志输出' : '查看日志失败';
    } else {
      output.write(result.output);
      serviceLogsOutput = output.toString();
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
      _commandRunnerCubit.setStatus('✗ 保存服务列表失败: $error');
    }
    notifyListeners();
  }
}
