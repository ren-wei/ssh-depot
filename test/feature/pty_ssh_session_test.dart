import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/ssh/pty_ssh_session.dart';

void main() {
  test('preserves raw trailing newline for xterm prompt placement', () {
    final chunk = PtySshSession.commandOutputChunkForTesting(
      commandOutput: '__sites_available__\n',
      rawOutput: '__sites_available__\n',
    );

    expect(chunk.text, '__sites_available__');
    expect(chunk.rawText, '__sites_available__\n');
  });

  test('requires boundary newline when streamed command output has no trailing newline', () {
    expect(PtySshSession.needsBoundaryNewlineForTesting(lastRawEndedWithNewline: false), isTrue);
    expect(PtySshSession.needsBoundaryNewlineForTesting(lastRawEndedWithNewline: true), isFalse);
  });

  test('does not stream incomplete command output lines before marker arrives', () {
    expect(PtySshSession.completeLineEndForTesting('__ssh-depot_ok__'), 0);
    expect(PtySshSession.completeLineEndForTesting('__ssh-depot_ok__\nnext'), '__ssh-depot_ok__\n'.length);
    expect(PtySshSession.completeLineEndForTesting('progress\rnext'), 'progress\r'.length);
  });

  test('ignores markers embedded in echoed wrapper commands', () {
    const marker = '__SSH_DEPOT_BEGIN_test__';
    final output = 'root@host:~# printf "\\n$marker\\n"\n'
        '$marker\n'
        'payload\n';

    final range = PtySshSession.standaloneMarkerRangeForTesting(output, marker);

    expect(range, isNotNull);
    expect(output.substring(range!.start, range.end), marker);
    expect(output.substring(0, range.start), contains('printf'));
  });

  test('ignores end markers embedded in echoed wrapper commands', () {
    const endPrefix = '__SSH_DEPOT_END_test__:';
    const expectedMarker = '__SSH_DEPOT_END_test__:0';
    final output = 'root@host:~# printf "\\n$endPrefix%s\\n" "\$__ssh_depot_exit"\n'
        '$expectedMarker\n'
        'root@host:~# ';

    final range = PtySshSession.standaloneEndMarkerRangeForTesting(output, endPrefix);

    expect(range, isNotNull);
    expect(output.substring(range!.start, range.end), expectedMarker);
    expect(output.substring(0, range.start), contains('printf'));
  });
}
