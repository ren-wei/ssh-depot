import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/core/terminal/terminal_control_sanitizer.dart';

void main() {
  test('strips ansi escape sequences and osc title controls', () {
    final sanitizer = TerminalControlSanitizer();

    expect(
      sanitizer.sanitize('\x1B]0;root@host\x07\x1B[32mok\x1B[0m\n'),
      'ok\n',
    );
  });

  test('keeps partial ansi escape state across chunks', () {
    final sanitizer = TerminalControlSanitizer();

    expect(sanitizer.sanitize('a\x1B['), 'a');
    expect(sanitizer.sanitize('32mok\x1B]0;title'), 'ok');
    expect(sanitizer.sanitize('\x07\n'), '\n');
  });

  test('normalizes carriage returns and removes backspaces', () {
    final sanitizer = TerminalControlSanitizer();

    expect(
      sanitizer.sanitize('downloading 10%\rdownloading 20%\nabc\b \bdone\r\n'),
      'downloading 10%\ndownloading 20%\nabdone\n',
    );
  });

  test('drops non printable controls but keeps tab and newline', () {
    final sanitizer = TerminalControlSanitizer();

    expect(sanitizer.sanitize('a\x00b\tc\x1Fd\n'), 'ab\tcd\n');
  });
}
