import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

void main() {
  test('quotes values for POSIX shell', () {
    expect(shellQuote('nginx'), "'nginx'");
    expect(shellQuote("a'b"), "'a'\"'\"'b'");
  });
}
