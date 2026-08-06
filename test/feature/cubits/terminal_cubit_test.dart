import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/core/process/process_output_chunk.dart';
import 'package:ssh_depot/feature/cubits/terminal_cubit.dart';

void main() {
  test('appends sanitized output and preserves raw output', () {
    final cubit = TerminalCubit();

    cubit.appendOutput(const ProcessOutputChunk(text: '\x1B[32mok\x1B[0m\n', rawText: 'raw\n', isStdErr: false));

    expect(cubit.output, 'ok\n');
    expect(cubit.rawOutput, 'raw\r\n');
    expect(cubit.lastVisibleLine, 'ok');
  });

  test('uses raw output when the visible chunk is empty', () {
    final cubit = TerminalCubit();

    cubit.appendOutput(const ProcessOutputChunk(
      text: '',
      rawText: 'permission denied\n',
      isStdErr: true,
    ));

    expect(cubit.output, 'permission denied\n');
    expect(cubit.terminalRawText, 'permission denied\r\n');
  });

  test('normalizes raw line feeds for xterm rendering', () {
    final cubit = TerminalCubit();

    cubit.append('first\nsecond\r\nthird');

    expect(cubit.terminalRawText, 'first\r\nsecond\r\nthird');
  });

  test('toggles expands and clears output', () {
    final cubit = TerminalCubit()..append('text');

    cubit.toggleExpanded();
    expect(cubit.expanded, isTrue);
    expect(cubit.terminalExpanded, isTrue);

    cubit.setExpanded(true);
    expect(cubit.expanded, isTrue);

    cubit.clear();
    expect(cubit.output, isEmpty);
    expect(cubit.terminalRawText, isEmpty);
  });
}
