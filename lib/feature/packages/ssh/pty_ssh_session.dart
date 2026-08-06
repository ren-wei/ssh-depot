import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:pty2/pty2.dart';
import 'package:ssh_depot/core/process/process_output_chunk.dart';
import 'package:ssh_depot/core/terminal/terminal_control_sanitizer.dart';

import 'shell_session.dart';
import 'ssh_target.dart';

class PtySshSession implements ShellSession {
  static const hostKeyPromptExitCode = -2;

  PseudoTerminal? _pty;
  StreamSubscription<String>? _outputSubscription;
  SshTarget? _target;
  _RunningCommand? _runningCommand;
  void Function(ProcessOutputChunk chunk)? _idleOutput;
  final TerminalControlSanitizer _sanitizer = TerminalControlSanitizer();
  String _pendingOutput = '';
  String _pendingRawOutput = '';
  String _openDetectionOutput = '';
  Completer<int>? _openFailureCompleter;
  PseudoTerminal? _pendingOpenCommandPty;
  String? _pendingOpenCommand;
  Timer? _pendingOpenCommandTimer;
  bool _isCapturingCommandOutput = false;
  bool _lastCommandRawEndedWithNewline = true;

  @override
  bool get isOpen => _pty != null;

  @override
  bool matches(SshTarget target) {
    final current = _target;
    return current != null && current.host == target.host && current.user == target.user;
  }

  @override
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
        'bash',
        bashArgumentsForTesting,
        environment: {
          ...Platform.environment,
          'BASH_SILENCE_DEPRECATION_WARNING': '1',
          'PS1': r'\u@\h:\w\$ ',
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
      _openDetectionOutput = '';
      _openFailureCompleter = Completer<int>();
      _pendingOpenCommandPty = pty;
      _pendingOpenCommand = _sshOpenCommand(target);
      _isCapturingCommandOutput = false;
      _lastCommandRawEndedWithNewline = true;
      var outputDone = false;
      var processExited = false;
      void clearIfFinished() {
        if (outputDone && processExited && identical(_pty, pty)) {
          _clearSessionState(keepPty: false);
        }
      }

      _outputSubscription = pty.out.listen(_handleOutput, onError: (Object error) {
        final running = _runningCommand;
        final chunk = ProcessOutputChunk(text: '$error\n', isStdErr: true);
        if (running != null && !running.completer.isCompleted) {
          running.onOutput(chunk);
          running.completer.complete(-1);
        } else {
          onOutput(chunk);
        }
      }, onDone: () {
        outputDone = true;
        clearIfFinished();
      });
      unawaited(pty.exitCode.then((exitCode) {
        if (!identical(_pty, pty)) {
          return;
        }
        final running = _runningCommand;
        final effectiveExitCode = exitCode == 0 ? -1 : exitCode;
        final openFailure = _openFailureCompleter;
        if (openFailure != null && !openFailure.isCompleted) {
          openFailure.complete(effectiveExitCode);
        }
        if (running != null && !running.completer.isCompleted) {
          running.completer.complete(effectiveExitCode);
        }
        processExited = true;
        clearIfFinished();
      }));

      _pendingOpenCommandTimer = Timer(const Duration(milliseconds: 300), () {
        _writePendingOpenCommand(reason: 'fallback timer');
      });

      if (timeout == null) {
        return 0;
      }
      return await Future.any<int>([
        _openFailureCompleter!.future,
        Future<int>.delayed(const Duration(milliseconds: 800), () {
          return _pty == null ? -1 : 0;
        }),
      ]).timeout(timeout, onTimeout: () {
        close();
        return -1;
      });
    } catch (error) {
      close();
      onOutput(ProcessOutputChunk(text: '$error\n', isStdErr: true));
      return -1;
    }
  }

  @override
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
    _openDetectionOutput = '';
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
        _resetRunningBuffers();
      });
    }

    pty.write(_wrapCommand(command, id));
    final exitCode = await running.completer.future;
    timer?.cancel();
    if (identical(_runningCommand, running)) {
      _resetRunningBuffers();
    }
    return exitCode;
  }

  @override
  bool interrupt() {
    final pty = _pty;
    if (pty == null) {
      return false;
    }
    pty.write('\x03');
    return true;
  }

  @override
  void close() {
    _outputSubscription?.cancel();
    _outputSubscription = null;
    _runningCommand = null;
    _target = null;
    _idleOutput = null;
    _pendingOutput = '';
    _pendingRawOutput = '';
    _openFailureCompleter = null;
    _pendingOpenCommandPty = null;
    _pendingOpenCommand = null;
    _pendingOpenCommandTimer?.cancel();
    _pendingOpenCommandTimer = null;
    _isCapturingCommandOutput = false;
    _lastCommandRawEndedWithNewline = true;
    final pty = _pty;
    _pty = null;
    pty?.kill();
  }

  void _handleOutput(String data) {
    final cleanData = _sanitizer.sanitize(data);
    final running = _runningCommand;
    if (cleanData.isEmpty) {
      if (running == null) {
        _idleOutput?.call(ProcessOutputChunk(text: '', rawText: data, isStdErr: false));
      } else {
        _pendingRawOutput += data;
      }
      return;
    }
    if (running == null) {
      _openDetectionOutput += cleanData;
      if (_openDetectionOutput.length > 4000) {
        _openDetectionOutput = _openDetectionOutput.substring(_openDetectionOutput.length - 4000);
      }
      _completeOpenFailureIfNeeded(cleanData);
      _idleOutput?.call(ProcessOutputChunk(text: cleanData, rawText: data, isStdErr: false));
      if (_looksReadyForInput(cleanData)) {
        _writePendingOpenCommand(reason: 'prompt detected');
      }
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
      if (beginRange == null) {
        _trimPendingPrefix();
        return;
      }
      _pendingOutput = _stripLeadingNewline(_pendingOutput.substring(beginRange.end));
      final rawBeginRange = standaloneMarkerRangeForTesting(_pendingRawOutput, beginMarker);
      _pendingRawOutput =
          rawBeginRange == null ? '' : _stripLeadingNewline(_pendingRawOutput.substring(rawBeginRange.end));
      _isCapturingCommandOutput = true;
    }

    final endRange = standaloneEndMarkerRangeForTesting(_pendingOutput, endPrefix);
    if (endRange == null) {
      final outputEnd = completeLineEndForTesting(_pendingOutput);
      final rawEnd = completeLineEndForTesting(_pendingRawOutput);
      if (outputEnd > 0 && rawEnd > 0) {
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

    final commandOutput = _pendingOutput.substring(0, endRange.start);
    if (commandOutput.isNotEmpty) {
      final rawEndRange = standaloneEndMarkerRangeForTesting(_pendingRawOutput, endPrefix);
      final rawOutput = rawEndRange == null ? commandOutput : _pendingRawOutput.substring(0, rawEndRange.start);
      final chunk = commandOutputChunkForTesting(commandOutput: commandOutput, rawOutput: rawOutput);
      _emitCommandOutput(running, text: chunk.text, rawText: chunk.rawText);
    }
    if (needsBoundaryNewlineForTesting(lastRawEndedWithNewline: _lastCommandRawEndedWithNewline)) {
      _emitCommandOutput(running, text: '', rawText: '\n');
    }

    final afterPrefix = _pendingOutput.substring(endRange.start + endPrefix.length);
    final exitMatch = RegExp(r'^(-?\d+)').firstMatch(afterPrefix);
    final exitCode = int.tryParse(exitMatch?.group(1) ?? '') ?? -1;
    if (!running.completer.isCompleted) {
      running.completer.complete(exitCode);
    }
    _resetRunningBuffers();
  }

  void _emitCommandOutput(_RunningCommand running, {required String text, required String rawText}) {
    running.onOutput(ProcessOutputChunk(text: text, rawText: rawText, isStdErr: false));
    if (rawText.isNotEmpty) {
      _lastCommandRawEndedWithNewline = _endsWithNewline(rawText);
    }
  }

  void _resetRunningBuffers() {
    _runningCommand = null;
    _pendingOutput = '';
    _pendingRawOutput = '';
    _isCapturingCommandOutput = false;
    _lastCommandRawEndedWithNewline = true;
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

  String _sshOpenCommand(SshTarget target) {
    return 'ssh -o BatchMode=yes ${_shellQuote(target.address)}\n';
  }

  String _shellQuote(String value) {
    return "'${value.replaceAll("'", r"""'\''""")}'";
  }

  void _completeOpenFailureIfNeeded(String output) {
    final openFailure = _openFailureCompleter;
    if (openFailure == null || openFailure.isCompleted) {
      return;
    }
    if (_looksLikeHostKeyPrompt(_openDetectionOutput)) {
      openFailure.complete(hostKeyPromptExitCode);
      return;
    }
    if (!_looksLikeSshOpenFailure(output)) {
      return;
    }
    openFailure.complete(255);
  }

  bool _looksLikeSshOpenFailure(String output) {
    return output.contains('Host key verification failed') ||
        output.contains('Permission denied') ||
        output.contains('Connection refused') ||
        output.contains('Connection timed out') ||
        output.contains('Operation timed out') ||
        output.contains('No route to host') ||
        output.contains('Could not resolve hostname') ||
        output.contains('REMOTE HOST IDENTIFICATION HAS CHANGED') ||
        output.contains('kex_exchange_identification') ||
        output.contains('Connection closed by') ||
        output.contains('Connection reset by');
  }

  bool _looksLikeHostKeyPrompt(String output) {
    return output.contains('The authenticity of host') ||
        output.contains('ED25519 key fingerprint is') ||
        output.contains('Are you sure you want to continue connecting');
  }

  bool _looksReadyForInput(String output) {
    final trimmed = output.trimRight();
    return trimmed.endsWith(r'$') || trimmed.endsWith('#') || trimmed.endsWith('>') || trimmed.contains(r'$ ');
  }

  void _writePendingOpenCommand({required String reason}) {
    final pty = _pendingOpenCommandPty;
    final command = _pendingOpenCommand;
    if (pty == null || command == null || !identical(_pty, pty)) {
      return;
    }
    _pendingOpenCommandPty = null;
    _pendingOpenCommand = null;
    _pendingOpenCommandTimer?.cancel();
    _pendingOpenCommandTimer = null;
    _idleOutput?.call(ProcessOutputChunk(text: command, rawText: command, isStdErr: false));
    pty.write(command);
  }

  String _markerId() {
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}_$random';
  }

  String _stripLeadingNewline(String value) {
    return value.replaceFirst(RegExp(r'^(?:\r\n|\n|\r)+'), '');
  }

  void _clearSessionState({required bool keepPty}) {
    _outputSubscription?.cancel();
    _outputSubscription = null;
    _runningCommand = null;
    _target = null;
    _idleOutput = null;
    _pendingOutput = '';
    _pendingRawOutput = '';
    _openDetectionOutput = '';
    _openFailureCompleter = null;
    _pendingOpenCommandPty = null;
    _pendingOpenCommand = null;
    _pendingOpenCommandTimer?.cancel();
    _pendingOpenCommandTimer = null;
    _isCapturingCommandOutput = false;
    _lastCommandRawEndedWithNewline = true;
    if (!keepPty) {
      _pty = null;
    }
  }

  static ProcessOutputChunk commandOutputChunkForTesting({
    required String commandOutput,
    required String rawOutput,
  }) {
    return ProcessOutputChunk(
      text: _stripTrailingNewlineStatic(commandOutput),
      rawText: rawOutput,
      isStdErr: false,
    );
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

  static String _stripTrailingNewlineStatic(String value) {
    return value.replaceFirst(RegExp(r'(?:\r\n|\n|\r)+$'), '');
  }

  static bool _endsWithNewline(String value) {
    return value.endsWith('\n') || value.endsWith('\r');
  }

  static const bashArgumentsForTesting = ['--noprofile', '--norc', '-i'];
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
