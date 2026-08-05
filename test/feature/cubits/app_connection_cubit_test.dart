import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/cubits/app_connection_cubit.dart';

void main() {
  test('requests connection with trimmed host and default user', () {
    final cubit = AppConnectionCubit();

    cubit.requestConnect(' example.com ');

    expect(cubit.hasTarget, isTrue);
    expect(cubit.target?.address, 'root@example.com');
    expect(cubit.target?.controlPath, startsWith('/tmp/ssh-depot-'));
    expect(cubit.statusLine, '正在连接 root@example.com');
  });

  test('handles empty host failure disconnect and manual status', () {
    final cubit = AppConnectionCubit();

    cubit.requestConnect(' ');
    expect(cubit.hasTarget, isFalse);
    expect(cubit.statusLine, '请输入 Host');

    cubit.requestConnect('host', user: ' admin ');
    cubit.markConnected();
    expect(cubit.statusLine, '✓ admin@host 已连接');

    cubit.failConnection('failed');
    expect(cubit.hasTarget, isFalse);
    expect(cubit.statusLine, 'failed');

    cubit.setStatus('custom');
    expect(cubit.statusLine, 'custom');
    cubit.disconnect();
    expect(cubit.statusLine, '已断开');
  });
}
