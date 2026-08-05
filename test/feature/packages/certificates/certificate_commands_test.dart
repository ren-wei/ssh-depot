import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/certificates/certificate_commands.dart';

void main() {
  test('builds certificate list command section and fields', () {
    final command = certificateListCommand();

    expect(command.summary, '刷新证书');
    expect(command.text, contains('echo "__certificates__"'));
    expect(command.text, contains('for certdir in /etc/letsencrypt/live/*; do'));
    expect(command.text, contains('printf "%s|%s|%s|%s|%s|%s\\n"'));
  });
}
