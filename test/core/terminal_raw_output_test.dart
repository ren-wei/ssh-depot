import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/core/terminal/terminal_raw_output.dart';

void main() {
  test('normalizes lone line feeds for xterm rendering', () {
    expect(
      TerminalRawOutput.normalizeForXterm('set -e\nif true; then\n  echo ok\nfi'),
      'set -e\r\nif true; then\r\n  echo ok\r\nfi',
    );
  });

  test('does not duplicate carriage returns for existing crlf', () {
    expect(
      TerminalRawOutput.normalizeForXterm('first\r\nsecond\nthird\r\n'),
      'first\r\nsecond\r\nthird\r\n',
    );
  });

  test('keeps marker and prompt separated when raw output has a trailing line feed', () {
    expect(
      TerminalRawOutput.normalizeForXterm('__sites_available__\nroot@host:~# '),
      '__sites_available__\r\nroot@host:~# ',
    );
  });

  test('clears stale prompt tail when carriage return overwrites a line', () {
    expect(
      TerminalRawOutput.normalizeForXterm('root@host:~# \r__ssh-depot_ok__\n'),
      'root@host:~# \r\x1B[K__ssh-depot_ok__\r\n',
    );
  });

  test('clears stale prompt tail for carriage-return-only chunks', () {
    expect(
      TerminalRawOutput.normalizeForXterm('\r__ssh-depot_ok__'),
      '\r\x1B[K__ssh-depot_ok__',
    );
  });
}
