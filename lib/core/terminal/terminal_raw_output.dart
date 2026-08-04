import 'dart:developer' as developer;

class TerminalRawOutput {
  const TerminalRawOutput._();

  static String normalizeForXterm(String value) {
    if (value.isEmpty || (!value.contains('\n') && !value.contains('\r'))) {
      return value;
    }
    final buffer = StringBuffer();
    for (var index = 0; index < value.length; index += 1) {
      final codeUnit = value.codeUnitAt(index);
      if (codeUnit == 0x0d) {
        buffer.writeCharCode(codeUnit);
        final nextIsLf = index + 1 < value.length && value.codeUnitAt(index + 1) == 0x0a;
        if (!nextIsLf) {
          buffer.write('\x1B[K');
          _debugLog('insert ESC[K after CR: ${_visible(value)}');
        }
        continue;
      }
      if (codeUnit == 0x0a && (index == 0 || value.codeUnitAt(index - 1) != 0x0d)) {
        buffer.write('\r');
      }
      buffer.writeCharCode(codeUnit);
    }
    final normalized = buffer.toString();
    if (normalized != value) {
      _debugLog('normalized raw: ${_visible(value)} -> ${_visible(normalized)}');
    }
    return normalized;
  }

  static void _debugLog(String message) {
    assert(() {
      developer.log(message, name: 'ssh_depot.terminal_raw');
      return true;
    }());
  }

  static String _visible(String value) {
    return value.replaceAll('\x1B', r'\x1B').replaceAll('\r', r'\r').replaceAll('\n', r'\n').replaceAll('\t', r'\t');
  }
}
