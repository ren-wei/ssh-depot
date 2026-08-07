import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/packages/command_runner/command_runner.dart';
import 'package:ssh_depot/feature/parts/packages/commands/package_commands.dart';

class PackagesCubit extends ChangeNotifier {
  PackagesCubit({required CommandRunner commandRunner}) : _commandRunner = commandRunner;

  final CommandRunner _commandRunner;

  Future<void> installPackage(String packageName) {
    final name = packageName.trim();
    if (!isSafePackageName(name)) {
      _commandRunner.setStatus('请输入有效包名');
      return Future.value();
    }
    return _commandRunner.runCommand(
      command: installPackageCommand(name),
      timeout: const Duration(minutes: 20),
    );
  }

  Future<void> removePackage(String packageName) {
    final name = packageName.trim();
    if (!isSafePackageName(name)) {
      _commandRunner.setStatus('请输入有效包名');
      return Future.value();
    }
    return _commandRunner.runCommand(
      command: removePackageCommand(name),
      timeout: const Duration(minutes: 10),
    );
  }
}
