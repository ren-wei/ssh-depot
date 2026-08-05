import 'package:flutter/foundation.dart';
import 'package:ssh_depot/core/process/process_output_chunk.dart';
import 'package:ssh_depot/core/terminal/terminal_line_buffer.dart';
import 'package:ssh_depot/core/terminal/terminal_raw_output.dart';

class TerminalCubit extends ChangeNotifier {
  final TerminalLineBuffer _lineBuffer = TerminalLineBuffer();
  final List<String> _terminalLines = [];
  final List<String> _terminalRawLines = [];

  bool terminalExpanded = false;
  String lastVisibleLine = '';

  List<String> get terminalLines => List.unmodifiable(_terminalLines);
  String get terminalRawText => _terminalRawLines.join();

  void appendOutput(ProcessOutputChunk chunk) {
    append(chunk.text, rawText: chunk.rawText);
  }

  void append(String text, {String? rawText}) {
    _terminalLines.add(text);
    _terminalRawLines.add(TerminalRawOutput.normalizeForXterm(rawText ?? text));
    _lineBuffer.append(text);
    lastVisibleLine = _lineBuffer.lastVisibleLine;
    notifyListeners();
  }

  void clear() {
    _terminalLines.clear();
    _terminalRawLines.clear();
    _lineBuffer.clear();
    lastVisibleLine = '';
    terminalExpanded = false;
    notifyListeners();
  }

  void toggleTerminal() {
    terminalExpanded = !terminalExpanded;
    notifyListeners();
  }
}
