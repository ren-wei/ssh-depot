import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/commands/ln_command.dart';

void main() {
  test('builds symbolic link command with default flags', () {
    final command = LnCommand.symbolic(source: '/a/source', target: '/b/target');

    expect(command.summary, '创建链接');
    expect(command.text, "ln -sfn '/a/source' '/b/target'");
  });

  test('supports raw source and reduced flags', () {
    expect(
      LnCommand.symbolicRaw(source: r'$target', target: '/path with space', force: false, noDereferenceTarget: false)
          .text,
      "ln -s \$target '/path with space'",
    );
  });
}
