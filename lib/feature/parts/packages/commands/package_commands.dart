import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/commands/apt_command.dart';

bool isSafePackageName(String value) {
  return RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9+._:-]*$').hasMatch(value);
}

Command installPackageCommand(String packageName) {
  return CommandSequence(
    summary: '安装软件包',
    commands: [
      AptCommand.update(),
      AptCommand.install(packageName),
    ],
  );
}

Command removePackageCommand(String packageName) {
  return AptCommand.remove(packageName);
}
