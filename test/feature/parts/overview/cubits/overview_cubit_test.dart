import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/parts/overview/cubits/overview_cubit.dart';

import '../../../fake_command_runner.dart';

void main() {
  test('refreshes overview through remote runner', () async {
    final runner = FakeCommandRunner()
      ..responses['刷新概览'] = const RemoteCommandResult(
        exitCode: 0,
        output: 'distribution=Debian\nkernel=6.1\nuptime=up 1 hour\ncpu=8\nmemory=16\ndisk=24\n',
      );
    final cubit = OverviewCubit(commandRunner: runner);

    await cubit.refreshOverview(const ['nginx.service']);

    expect(cubit.overviewLoading, isFalse);
    expect(cubit.overviewSnapshot?.distribution, 'Debian');
    expect(runner.commands.single, contains("for svc in 'nginx.service'; do"));
  });
}
