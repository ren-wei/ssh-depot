import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/packages/command_runner/operation_queue.dart';

void main() {
  test('runs operations sequentially in submission order', () async {
    final queue = OperationQueue();
    final events = <String>[];
    final firstCompleter = Completer<void>();

    final first = queue.run(() async {
      events.add('first-start');
      await firstCompleter.future;
      events.add('first-end');
      return 1;
    });
    final second = queue.run(() async {
      events.add('second');
      return 2;
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ['first-start']);
    firstCompleter.complete();

    expect(await first, 1);
    expect(await second, 2);
    expect(events, ['first-start', 'first-end', 'second']);
  });

  test('propagates operation errors and continues queue', () async {
    final queue = OperationQueue();

    expect(queue.run<int>(() async => throw StateError('boom')), throwsStateError);
    expect(await queue.run(() async => 2), 2);
  });
}
