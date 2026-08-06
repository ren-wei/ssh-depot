import 'package:flutter/foundation.dart';
import 'package:ssh_depot/core/process/process_output_chunk.dart';
import 'package:ssh_depot/core/terminal/terminal_control_sanitizer.dart';
import 'package:ssh_depot/core/terminal/terminal_raw_output.dart';

class TerminalCubit extends ChangeNotifier {
  final _sanitizer = TerminalControlSanitizer();
  final _buffer = StringBuffer();

  bool expanded = false;
  String output = '';
  String rawOutput = '';

  bool get terminalExpanded => expanded;
  String get terminalRawText => rawOutput;

  String get lastVisibleLine {
    final lines = output.trimRight().split('\n');
    return lines.isEmpty ? '' : lines.last.trim();
  }

  void append(String text, {String? rawText}) {
    _buffer.write(text);
    output = _buffer.toString();
    rawOutput += TerminalRawOutput.normalizeForXterm(rawText ?? text);
    notifyListeners();
  }

  void appendOutput(ProcessOutputChunk chunk) {
    var visibleText = _sanitizer.sanitize(chunk.text);
    if (visibleText.isEmpty && chunk.rawText != chunk.text) {
      visibleText = _sanitizer.sanitize(chunk.rawText);
    }
    append(visibleText, rawText: chunk.rawText);
  }

  void clear() {
    _buffer.clear();
    output = '';
    rawOutput = '';
    notifyListeners();
  }

  void toggleExpanded() {
    expanded = !expanded;
    notifyListeners();
  }

  void toggleTerminal() {
    toggleExpanded();
  }

  void setExpanded(bool value) {
    if (expanded == value) {
      return;
    }
    expanded = value;
    notifyListeners();
  }
}
