import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/commands/nginx_command.dart';

void main() {
  test('builds nginx syntax test command', () {
    final command = NginxCommand.test();

    expect(command.summary, '网站语法检查');
    expect(command.text, 'nginx -t');
  });
}
