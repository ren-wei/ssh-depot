import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/core/terminal/terminal_line_buffer.dart';

void main() {
  test('tracks last visible line and ignores empty ansi-only updates', () {
    final buffer = TerminalLineBuffer();

    buffer.append('apt update\n');
    buffer.append('\x1B[32mDone\x1B[0m\n');
    buffer.append('\x1B[0m');

    expect(buffer.lastVisibleLine, '\x1B[32mDone\x1B[0m');
  });
}
