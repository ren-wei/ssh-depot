import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/command_runner/operation_result.dart';

void main() {
  test('marks zero exit code as success', () {
    expect(const OperationResult(summary: 'ok', exitCode: 0).isSuccess, isTrue);
    expect(const OperationResult(summary: 'fail', exitCode: 1).isSuccess, isFalse);
  });
}
