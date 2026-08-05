import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/commands/find_command.dart';

void main() {
  test('builds file find command with basename output', () {
    final command = FindCommand.files('/etc/nginx/sites-available');

    expect(command.summary, '查找文件');
    expect(command.text, "find '/etc/nginx/sites-available' -maxdepth 1 -type f -printf \"%f\\n\" 2>/dev/null || true");
  });

  test('supports files or links and full path output', () {
    final command = FindCommand.filesOrLinks('/tmp/a b', maxDepth: 2, printBasename: false, ignoreErrors: false);

    expect(command.text, "find '/tmp/a b' -maxdepth 2 \\( -type f -o -type l \\) -print");
  });
}
