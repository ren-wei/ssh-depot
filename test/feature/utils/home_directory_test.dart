import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/utils/home_directory.dart';

void main() {
  test('resolves home directory from HOME before USERPROFILE', () {
    expect(resolveHomeDirectory(environment: const {'HOME': '/home/me', 'USERPROFILE': r'C:\Users\me'}), '/home/me');
  });

  test('falls back to USERPROFILE then current directory', () {
    expect(resolveHomeDirectory(environment: const {'HOME': ' ', 'USERPROFILE': r'C:\Users\me'}), r'C:\Users\me');
    expect(resolveHomeDirectory(environment: const {}), isNotEmpty);
  });
}
