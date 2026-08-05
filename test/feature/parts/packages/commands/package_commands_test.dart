import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/parts/packages/commands/package_commands.dart';

void main() {
  test('validates apt package names', () {
    expect(isSafePackageName('nginx'), isTrue);
    expect(isSafePackageName('libssl-dev'), isTrue);
    expect(isSafePackageName('bad package'), isFalse);
    expect(isSafePackageName(';rm'), isFalse);
  });

  test('quotes package names in apt commands', () {
    expect(installPackageCommand('nginx').text, "apt update && apt install -y 'nginx'");
    expect(removePackageCommand('nginx').text, "apt remove -y 'nginx'");
  });
}
