import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/cubits/operation_history_cubit.dart';

void main() {
  test('records newest operations first and caps at fifty', () {
    final cubit = OperationHistoryCubit();

    for (var i = 0; i < 55; i++) {
      cubit.record(summary: 'op$i', command: 'cmd$i', exitCode: i.isEven ? 0 : 1);
    }

    expect(cubit.records, hasLength(50));
    expect(cubit.records.first.summary, 'op54');
    expect(cubit.records.last.summary, 'op5');
    expect(cubit.recentOperations.first.succeeded, isTrue);
  });

  test('clears operation records', () {
    final cubit = OperationHistoryCubit()..record(summary: 'op', command: 'cmd', exitCode: 0);

    cubit.clear();

    expect(cubit.records, isEmpty);
  });
}
