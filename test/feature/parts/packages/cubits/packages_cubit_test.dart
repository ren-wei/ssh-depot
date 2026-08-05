import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/parts/packages/cubits/packages_cubit.dart';

import '../../../fake_remote_command_runner.dart';

void main() {
  test('rejects invalid package name before running command', () async {
    final runner = FakeRemoteCommandRunner();
    final cubit = PackagesCubit(commandRunner: runner);

    await cubit.installPackage('bad package');

    expect(runner.commands, isEmpty);
    expect(runner.statusLine, '请输入有效包名');
  });

  test('runs apt install command for valid package', () async {
    final runner = FakeRemoteCommandRunner();
    final cubit = PackagesCubit(commandRunner: runner);

    await cubit.installPackage('nginx');

    expect(runner.commands.single, "apt update && apt install -y 'nginx'");
  });
}
