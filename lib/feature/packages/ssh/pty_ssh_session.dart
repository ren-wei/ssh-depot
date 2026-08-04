import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:pty2/pty2.dart';

import '../../../core/process/process_output_chunk.dart';
import '../../../core/terminal/terminal_control_sanitizer.dart';
import 'ssh_target.dart';

class PtySshSession {
  PseudoTerminal? _pty;
  StreamSubscription<String>? _outputSubscription;
  SshTarget? _target;
  _RunningCommand? _runningCommand;
  void Function(ProcessOutputChunk chunk)? _idleOutput;
  final TerminalControlSanitizer _sanitizer = TerminalControlSanitizer();
  String _pendingOutput = '';
  String _pendingRawOutput = '';
  bool _isCapturingCommandOutput = false;
  bool _lastCommandRawEndedWithNewline = true;

  bool get isOpen => _pty != null;

  bool matches(SshTarget target) {
    final current = _target;
    return current != null && current.host == target.host && current.user == target.user;
  }

  Future<int> open({
    required SshTarget target,
    required void Function(ProcessOutputChunk chunk) onOutput,
    Duration? timeout,
  }) async {
    if (matches(target) && isOpen) {
      return 0;
    }
    close();

    try {
      final pty = PseudoTerminal.start(
        'ssh',
        [
          '-o',
          'BatchMode=yes',
          '-o',
          'ConnectTimeout=10',
          target.address,
        ],
        environment: {
          ...Platform.environment,
          'TERM': Platform.environment['TERM'] ?? 'xterm-256color',
        },
        raw: true,
      );
      pty.resize(120, 40);
      _pty = pty;
      _target = target;
      _idleOutput = onOutput;
      _pendingOutput = '';
      _pendingRawOutput = '';
      _isCapturingCommandOutput = false;
      _lastCommandRawEndedWithNewline = true;
      _outputSubscription = pty.out.listen(_handleOutput, onError: (Object error) {
        final running = _runningCommand;
        if (running != null && !running.completer.isCompleted) {
          running.onOutput(ProcessOutputChunk(text: '$error\n', isStdErr: true));
          running.completer.complete(-1);
        } else {
          onOutput(ProcessOutputChunk(text: '$error\n', isStdErr: true));
        }
      });
      unawaited(pty.exitCode.then((exitCode) {
        if (!identical(_pty, pty)) {
          return;
        }
        final running = _runningCommand;
        if (running != null && !running.completer.isCompleted) {
          running.onOutput(ProcessOutputChunk(text: '\nSSH 会话已退出: $exitCode\n', isStdErr: true));
          running.completer.complete(exitCode == 0 ? -1 : exitCode);
        } else if (exitCode != 0) {
          _idleOutput?.call(ProcessOutputChunk(text: '\nSSH 会话已退出: $exitCode\n', isStdErr: true));
        }
        _clearSessionState(keepPty: false);
      }));

      if (timeout == null) {
        return 0;
      }
      return await Future<int>.delayed(const Duration(milliseconds: 250), () {
        return _pty == null ? -1 : 0;
      }).timeout(timeout, onTimeout: () {
        close();
        return -1;
      });
    } catch (error) {
      close();
      onOutput(ProcessOutputChunk(text: '$error\n', isStdErr: true));
      return -1;
    }
  }

  Future<int> run({
    required String command,
    required void Function(ProcessOutputChunk chunk) onOutput,
    Duration? timeout,
  }) async {
    final pty = _pty;
    if (pty == null) {
      onOutput(const ProcessOutputChunk(text: 'SSH 会话未建立\n', isStdErr: true));
      return -1;
    }
    if (_runningCommand != null) {
      onOutput(const ProcessOutputChunk(text: '已有命令正在执行\n', isStdErr: true));
      return -1;
    }

    final id = _markerId();
    final running = _RunningCommand(
      id: id,
      onOutput: onOutput,
      completer: Completer<int>(),
    );
    _runningCommand = running;
    _pendingOutput = '';
    _pendingRawOutput = '';
    _isCapturingCommandOutput = false;
    _lastCommandRawEndedWithNewline = true;

    Timer? timer;
    if (timeout != null) {
      timer = Timer(timeout, () {
        if (!running.completer.isCompleted) {
          onOutput(ProcessOutputChunk(text: '\n命令超时: ${timeout.inSeconds}s\n', isStdErr: true));
          pty.write('\x03');
          running.completer.complete(-1);
        }
        _runningCommand = null;
        _pendingOutput = '';
        _pendingRawOutput = '';
        _isCapturingCommandOutput = false;
        _lastCommandRawEndedWithNewline = true;
      });
    }

    pty.write(_wrapCommand(command, id));
    final exitCode = await running.completer.future;
    timer?.cancel();
    if (identical(_runningCommand, running)) {
      _runningCommand = null;
      _pendingOutput = '';
      _pendingRawOutput = '';
      _isCapturingCommandOutput = false;
      _lastCommandRawEndedWithNewline = true;
    }
    return exitCode;
  }

  bool interrupt() {
    final pty = _pty;
    if (pty == null) {
      return false;
    }
    pty.write('\x03');
    return true;
  }

  void close() {
    _outputSubscription?.cancel();
    _outputSubscription = null;
    _runningCommand = null;
    _target = null;
    _idleOutput = null;
    _pendingOutput = '';
    _pendingRawOutput = '';
    _isCapturingCommandOutput = false;
    _lastCommandRawEndedWithNewline = true;
    final pty = _pty;
    _pty = null;
    pty?.kill();
  }

  void _handleOutput(String data) {
    final cleanData = _sanitizer.sanitize(data);
    final running = _runningCommand;
    _debugLog(
      'chunk raw=${_visible(data)} clean=${_visible(cleanData)} running=${running != null} capturing=$_isCapturingCommandOutput',
    );
    if (cleanData.isEmpty) {
      if (running == null) {
        _idleOutput?.call(ProcessOutputChunk(text: '', rawText: data, isStdErr: false));
      } else {
        _pendingRawOutput += data;
      }
      return;
    }
    if (running == null) {
      _idleOutput?.call(ProcessOutputChunk(text: cleanData, rawText: data, isStdErr: false));
      return;
    }

    _pendingOutput += cleanData;
    _pendingRawOutput += data;
    _drainPendingOutput(running);
  }

  void _drainPendingOutput(_RunningCommand running) {
    final beginMarker = '__SSH_DEPOT_BEGIN_${running.id}__';
    final endPrefix = '__SSH_DEPOT_END_${running.id}__:';

    if (!_isCapturingCommandOutput) {
      final beginRange = standaloneMarkerRangeForTesting(_pendingOutput, beginMarker);
      final beginIndex = beginRange?.start ?? -1;
      if (beginIndex < 0) {
        _trimPendingPrefix();
        return;
      }
      _debugLog('begin marker matched at $beginIndex');
      _pendingOutput = _pendingOutput.substring(beginRange!.end);
      _pendingOutput = _stripLeadingNewline(_pendingOutput);
      final rawBeginRange = standaloneMarkerRangeForTesting(_pendingRawOutput, beginMarker);
      if (rawBeginRange != null) {
        _debugLog('raw begin marker matched at ${rawBeginRange.start}');
        _pendingRawOutput = _pendingRawOutput.substring(rawBeginRange.end);
        _pendingRawOutput = _stripLeadingNewline(_pendingRawOutput);
      } else {
        _pendingRawOutput = '';
      }
      _isCapturingCommandOutput = true;
    }

    final endRange = standaloneEndMarkerRangeForTesting(_pendingOutput, endPrefix);
    final endIndex = endRange?.start ?? -1;
    if (endIndex < 0) {
      final outputEnd = completeLineEndForTesting(_pendingOutput);
      final rawEnd = completeLineEndForTesting(_pendingRawOutput);
      if (outputEnd > 0 && rawEnd > 0) {
        _debugLog(
          'emit complete line text=${_visible(_pendingOutput.substring(0, outputEnd))} raw=${_visible(_pendingRawOutput.substring(0, rawEnd))}',
        );
        _emitCommandOutput(
          running,
          text: _pendingOutput.substring(0, outputEnd),
          rawText: _pendingRawOutput.substring(0, rawEnd),
        );
        _pendingOutput = _pendingOutput.substring(outputEnd);
        _pendingRawOutput = _pendingRawOutput.substring(rawEnd);
      }
      return;
    }

    final commandOutput = _pendingOutput.substring(0, endIndex);
    if (commandOutput.isNotEmpty) {
      final rawEndRange = standaloneEndMarkerRangeForTesting(_pendingRawOutput, endPrefix);
      final rawOutput = rawEndRange != null ? _pendingRawOutput.substring(0, rawEndRange.start) : commandOutput;
      final chunk = commandOutputChunkForTesting(commandOutput: commandOutput, rawOutput: rawOutput);
      _debugLog(
          'end marker matched at $endIndex emit tail text=${_visible(chunk.text)} raw=${_visible(chunk.rawText)}');
      _emitCommandOutput(running, text: chunk.text, rawText: chunk.rawText);
    }
    if (needsBoundaryNewlineForTesting(lastRawEndedWithNewline: _lastCommandRawEndedWithNewline)) {
      _debugLog('emit boundary newline before prompt');
      _emitCommandOutput(running, text: '', rawText: '\n');
    }
    final afterPrefix = _pendingOutput.substring(endRange!.start + endPrefix.length);
    final exitMatch = RegExp(r'^(-?\d+)').firstMatch(afterPrefix);
    final exitCode = int.tryParse(exitMatch?.group(1) ?? '') ?? -1;
    if (!running.completer.isCompleted) {
      running.completer.complete(exitCode);
    }
    _pendingOutput = '';
    _pendingRawOutput = '';
    _isCapturingCommandOutput = false;
    _lastCommandRawEndedWithNewline = true;
  }

  void _emitCommandOutput(_RunningCommand running, {required String text, required String rawText}) {
    _debugLog('emit output text=${_visible(text)} raw=${_visible(rawText)}');
    running.onOutput(ProcessOutputChunk(text: text, rawText: rawText, isStdErr: false));
    if (rawText.isNotEmpty) {
      _lastCommandRawEndedWithNewline = _endsWithNewline(rawText);
    }
  }

  void _trimPendingPrefix() {
    const maxMarkerLength = 80;
    if (_pendingOutput.length > maxMarkerLength) {
      _pendingOutput = _pendingOutput.substring(_pendingOutput.length - maxMarkerLength);
    }
    if (_pendingRawOutput.length > maxMarkerLength) {
      _pendingRawOutput = _pendingRawOutput.substring(_pendingRawOutput.length - maxMarkerLength);
    }
  }

  String _wrapCommand(String command, String id) {
    final begin = '__SSH_DEPOT_BEGIN_${id}__';
    final end = '__SSH_DEPOT_END_${id}__';
    return 'printf "\\n$begin\\n"\n'
        '(\n'
        '$command\n'
        ')\n'
        '__ssh_depot_exit=\$?\n'
        'printf "\\n$end:%s\\n" "\$__ssh_depot_exit"\n';
  }

  String _markerId() {
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}_$random';
  }

  String _stripLeadingNewline(String value) {
    return value.replaceFirst(RegExp(r'^(?:\r\n|\n|\r)+'), '');
  }

  static ProcessOutputChunk commandOutputChunkForTesting({
    required String commandOutput,
    required String rawOutput,
  }) {
    return ProcessOutputChunk(text: _stripTrailingNewlineStatic(commandOutput), rawText: rawOutput, isStdErr: false);
  }

  static bool needsBoundaryNewlineForTesting({required bool lastRawEndedWithNewline}) {
    return !lastRawEndedWithNewline;
  }

  static int completeLineEndForTesting(String value) {
    final lfIndex = value.lastIndexOf('\n');
    final crIndex = value.lastIndexOf('\r');
    final index = lfIndex > crIndex ? lfIndex : crIndex;
    return index < 0 ? 0 : index + 1;
  }

  static MarkerRange? standaloneMarkerRangeForTesting(String value, String marker) {
    var searchFrom = 0;
    while (searchFrom < value.length) {
      final index = value.indexOf(marker, searchFrom);
      if (index < 0) {
        return null;
      }
      final end = index + marker.length;
      if (_hasLineBoundaryBefore(value, index) && _hasLineBoundaryAfter(value, end)) {
        return MarkerRange(index, end);
      }
      searchFrom = end;
    }
    return null;
  }

  static MarkerRange? standaloneEndMarkerRangeForTesting(String value, String prefix) {
    var searchFrom = 0;
    while (searchFrom < value.length) {
      final index = value.indexOf(prefix, searchFrom);
      if (index < 0) {
        return null;
      }
      var end = index + prefix.length;
      while (end < value.length) {
        final codeUnit = value.codeUnitAt(end);
        if (codeUnit < 0x30 || codeUnit > 0x39) {
          break;
        }
        end += 1;
      }
      if (_hasLineBoundaryBefore(value, index) && end > index + prefix.length && _hasLineBoundaryAfter(value, end)) {
        return MarkerRange(index, end);
      }
      searchFrom = end;
    }
    return null;
  }

  static bool _hasLineBoundaryBefore(String value, int index) {
    if (index == 0) {
      return true;
    }
    final codeUnit = value.codeUnitAt(index - 1);
    return codeUnit == 0x0a || codeUnit == 0x0d;
  }

  static bool _hasLineBoundaryAfter(String value, int index) {
    if (index >= value.length) {
      return true;
    }
    final codeUnit = value.codeUnitAt(index);
    return codeUnit == 0x0a || codeUnit == 0x0d;
  }

  static bool _endsWithNewline(String value) {
    return value.endsWith('\n') || value.endsWith('\r');
  }

  static void _debugLog(String message) {
    assert(() {
      developer.log(message, name: 'ssh_depot.pty');
      return true;
    }());
  }

  static String _visible(String value) {
    return value.replaceAll('\x1B', r'\x1B').replaceAll('\r', r'\r').replaceAll('\n', r'\n').replaceAll('\t', r'\t');
  }

  static String _stripTrailingNewlineStatic(String value) {
    return value.replaceFirst(RegExp(r'(?:\r\n|\n|\r)+$'), '');
  }

  void _clearSessionState({required bool keepPty}) {
    _outputSubscription?.cancel();
    _outputSubscription = null;
    _runningCommand = null;
    _target = null;
    _idleOutput = null;
    _pendingOutput = '';
    _pendingRawOutput = '';
    _isCapturingCommandOutput = false;
    _lastCommandRawEndedWithNewline = true;
    if (!keepPty) {
      _pty = null;
    }
  }
}

class MarkerRange {
  const MarkerRange(this.start, this.end);

  final int start;
  final int end;
}

class _RunningCommand {
  const _RunningCommand({
    required this.id,
    required this.onOutput,
    required this.completer,
  });

  final String id;
  final void Function(ProcessOutputChunk chunk) onOutput;
  final Completer<int> completer;
}
