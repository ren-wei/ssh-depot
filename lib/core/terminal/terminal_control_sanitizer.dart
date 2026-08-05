class TerminalControlSanitizer {
  String _pendingEscape = '';

  String sanitize(String input) {
    if (input.isEmpty) {
      return input;
    }

    final source = _pendingEscape + input;
    _pendingEscape = '';
    final pendingEscapeStart = _incompleteEscapeStart(source);
    final completeSource = pendingEscapeStart == null ? source : source.substring(0, pendingEscapeStart);
    if (pendingEscapeStart != null) {
      _pendingEscape = source.substring(pendingEscapeStart);
    }

    final withoutEscapes = completeSource
        .replaceAll(RegExp(r'\x1B\][^\x07]*(?:\x07|\x1B\\)'), '')
        .replaceAll(RegExp(r'\x1B[P_X^][\s\S]*?\x1B\\'), '')
        .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '')
        .replaceAll(RegExp(r'\x1B[ -/]*[@-~]'), '');

    final output = StringBuffer();
    var currentLine = StringBuffer();

    void flushLine({required bool newline}) {
      output.write(currentLine);
      currentLine = StringBuffer();
      if (newline) {
        output.write('\n');
      }
    }

    for (var index = 0; index < withoutEscapes.length; index += 1) {
      final codeUnit = withoutEscapes.codeUnitAt(index);
      switch (codeUnit) {
        case 0x08:
        case 0x7f:
          final value = currentLine.toString();
          if (value.isNotEmpty) {
            currentLine = StringBuffer(value.substring(0, value.length - 1));
          }
        case 0x0d:
          final nextIsLf = index + 1 < withoutEscapes.length && withoutEscapes.codeUnitAt(index + 1) == 0x0a;
          flushLine(newline: true);
          if (nextIsLf) {
            index += 1;
          }
        case 0x0a:
          flushLine(newline: true);
        case 0x09:
          currentLine.write('\t');
        default:
          if (codeUnit >= 0x20) {
            currentLine.writeCharCode(codeUnit);
          }
      }
    }

    if (currentLine.isNotEmpty) {
      output.write(currentLine);
    }
    return output.toString();
  }

  int? _incompleteEscapeStart(String value) {
    final escapeIndex = value.lastIndexOf('\x1B');
    if (escapeIndex < 0) {
      return null;
    }
    final sequence = value.substring(escapeIndex);
    if (sequence.length == 1) {
      return escapeIndex;
    }

    final second = sequence.codeUnitAt(1);
    if (second == 0x5b) {
      for (var index = 2; index < sequence.length; index += 1) {
        final codeUnit = sequence.codeUnitAt(index);
        if (codeUnit >= 0x40 && codeUnit <= 0x7e) {
          return null;
        }
      }
      return escapeIndex;
    }
    if (second == 0x5d) {
      return sequence.contains('\x07') || sequence.contains('\x1B\\') ? null : escapeIndex;
    }
    if (second == 0x50 || second == 0x5f || second == 0x58 || second == 0x5e) {
      return sequence.contains('\x1B\\') ? null : escapeIndex;
    }
    return null;
  }
}
