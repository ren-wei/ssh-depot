import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'process_output_chunk.dart';

class LocalProcessRunner {
  Future<int> start({
    required String executable,
    required List<String> arguments,
    required void Function(ProcessOutputChunk chunk) onOutput,
    Duration? timeout,
  }) async {
    final process = await Process.start(executable, arguments);
    Timer? timer;

    if (timeout != null) {
      timer = Timer(timeout, process.kill);
    }

    final stdoutDone = process.stdout.transform(utf8.decoder).listen((text) {
      onOutput(ProcessOutputChunk(text: text, isStdErr: false));
    }).asFuture<void>();

    final stderrDone = process.stderr.transform(utf8.decoder).listen((text) {
      onOutput(ProcessOutputChunk(text: text, isStdErr: true));
    }).asFuture<void>();

    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    timer?.cancel();

    return exitCode;
  }
}
