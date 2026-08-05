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
        }
        continue;
      }
      if (codeUnit == 0x0a && (index == 0 || value.codeUnitAt(index - 1) != 0x0d)) {
        buffer.write('\r');
      }
      buffer.writeCharCode(codeUnit);
    }
    return buffer.toString();
  }
}
