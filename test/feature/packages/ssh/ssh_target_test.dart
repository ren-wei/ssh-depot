import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

void main() {
  test('builds ssh address with default and custom user', () {
    expect(const SshTarget(host: 'host').address, 'root@host');
    expect(const SshTarget(host: 'host', user: 'admin', controlPath: '/tmp/sock').address, 'admin@host');
  });
}
