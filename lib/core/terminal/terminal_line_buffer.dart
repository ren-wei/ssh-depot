class TerminalLineBuffer {
  String _lastVisibleLine = '';

  String get lastVisibleLine => _lastVisibleLine;

  void clear() {
    _lastVisibleLine = '';
  }

  void append(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final stripped = _stripAnsi(line).trim();
      if (stripped.isNotEmpty) {
        _lastVisibleLine = line;
      }
    }
  }

  String _stripAnsi(String value) {
    return value.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
  }
}
