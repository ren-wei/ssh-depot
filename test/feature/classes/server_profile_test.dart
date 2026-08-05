import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/server_profile.dart';

void main() {
  test('uses name host and user for display and target', () {
    const server = ServerProfile(name: 'prod', host: '1.2.3.4', user: 'admin');

    expect(server.target, 'admin@1.2.3.4');
    expect(server.displayName, 'prod');
    expect(const ServerProfile(name: '  ', host: 'host').displayName, 'host');
  });

  test('copyWith preserves unspecified fields and accepts null boundary through omission', () {
    const server = ServerProfile(name: 'prod', host: 'host', user: 'root', remark: 'main');
    final copy = server.copyWith(name: 'staging');

    expect(copy.name, 'staging');
    expect(copy.host, 'host');
    expect(copy.user, 'root');
    expect(copy.remark, 'main');
  });
}
