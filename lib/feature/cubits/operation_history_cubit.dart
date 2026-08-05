import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';

class OperationHistoryCubit extends ChangeNotifier {
  List<OperationRecord> records = const [];

  List<OperationRecord> get recentOperations => List.unmodifiable(records);

  void record({
    required String summary,
    required String command,
    required int exitCode,
  }) {
    records = [
      OperationRecord(
        timestamp: DateTime.now(),
        summary: summary,
        command: command,
        exitCode: exitCode,
      ),
      ...records,
    ].take(50).toList(growable: false);
    notifyListeners();
  }

  void clear() {
    records = const [];
    notifyListeners();
  }
}
