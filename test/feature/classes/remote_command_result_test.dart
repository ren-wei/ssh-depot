import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';

void main() {
  test('succeeded is based on exit code', () {
    expect(const RemoteCommandResult(exitCode: 0, output: '').succeeded, isTrue);
    expect(const RemoteCommandResult(exitCode: -1, output: 'error').succeeded, isFalse);
  });
}
