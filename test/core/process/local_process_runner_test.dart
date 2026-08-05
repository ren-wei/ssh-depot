import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/core/process/local_process_runner.dart';

void main() {
  test('captures stdout stderr and exit code from a local process', () async {
    final runner = LocalProcessRunner();
    final chunks = <String>[];
    final stderrFlags = <bool>[];

    final exitCode = await runner.start(
      executable: '/bin/sh',
      arguments: const ['-c', 'printf out; printf err >&2; exit 3'],
      onOutput: (chunk) {
        chunks.add(chunk.text);
        stderrFlags.add(chunk.isStdErr);
      },
    );

    expect(exitCode, 3);
    expect(chunks.join(), contains('out'));
    expect(chunks.join(), contains('err'));
    expect(stderrFlags, containsAll([false, true]));
    expect(runner.killActive(), isFalse);
  });
}
