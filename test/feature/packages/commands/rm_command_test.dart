import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/commands/rm_command.dart';

void main() {
  test('builds forced rm command for multiple files', () {
    final command = RmCommand.files(['/a', '/b c']);

    expect(command.summary, '删除文件');
    expect(command.text, "rm -f '/a' '/b c'");
  });

  test('supports non-forced and empty path boundary', () {
    expect(RmCommand.files(['/a'], force: false).text, "rm '/a'");
    expect(RmCommand.files([]).text, 'rm -f ');
  });
}
