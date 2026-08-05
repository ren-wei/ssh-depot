import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';

import '../utils/packages_utils.dart';

class PackagesCubit extends ChangeNotifier {
  PackagesCubit({required CommandRunnerCubit commandRunnerCubit}) : _commandRunnerCubit = commandRunnerCubit;

  final CommandRunnerCubit _commandRunnerCubit;

  Future<void> installPackage(String packageName) {
    final name = packageName.trim();
    if (!isSafePackageName(name)) {
      _commandRunnerCubit.setStatus('请输入有效包名');
      return Future.value();
    }
    return _commandRunnerCubit.runRemote(
      summary: '安装 $name',
      command: installPackageCommand(name),
      timeout: const Duration(minutes: 20),
    );
  }

  Future<void> removePackage(String packageName) {
    final name = packageName.trim();
    if (!isSafePackageName(name)) {
      _commandRunnerCubit.setStatus('请输入有效包名');
      return Future.value();
    }
    return _commandRunnerCubit.runRemote(
      summary: '卸载 $name',
      command: removePackageCommand(name),
      timeout: const Duration(minutes: 10),
    );
  }
}
