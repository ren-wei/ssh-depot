import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/core/process/process_output_chunk.dart';

void main() {
  test('uses text as raw text when raw text is omitted', () {
    const chunk = ProcessOutputChunk(text: 'out', isStdErr: false);

    expect(chunk.rawText, 'out');
    expect(chunk.isStdErr, isFalse);
  });

  test('preserves explicit raw text and stderr flag', () {
    const chunk = ProcessOutputChunk(text: 'clean', rawText: '\x1B[31mclean\x1B[0m', isStdErr: true);

    expect(chunk.rawText, '\x1B[31mclean\x1B[0m');
    expect(chunk.isStdErr, isTrue);
  });
}
