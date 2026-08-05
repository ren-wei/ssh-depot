import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/parts/ssl/cubits/ssl_cubit.dart';

import '../../../fake_remote_command_runner.dart';

void main() {
  test('rejects empty email before requesting certificate', () async {
    final runner = FakeRemoteCommandRunner();
    final cubit = SslCubit(commandRunner: runner);

    final result = await cubit.requestCertificate(
      domain: 'example.com',
      email: '',
      useWebroot: false,
      webroot: '',
    );

    expect(result, isNull);
    expect(runner.commands, isEmpty);
    expect(runner.statusLine, '请输入邮箱');
  });

  test('refreshes certificates from runner output', () async {
    final runner = FakeRemoteCommandRunner()
      ..responses['刷新证书列表'] = const RemoteCommandResult(
        exitCode: 0,
        output:
            '__certificates__\nexample.com|1893456000|CN=R3|/etc/letsencrypt/live/example.com/fullchain.pem|/etc/letsencrypt/live/example.com/privkey.pem|example.com\n',
      );
    final cubit = SslCubit(commandRunner: runner);

    await cubit.refreshCertificates();

    expect(cubit.nginxCertificates.single.certName, 'example.com');
  });
}
