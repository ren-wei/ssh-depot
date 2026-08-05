import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';

class OperationHistoryCubit extends ChangeNotifier {
  final List<OperationRecord> _recentOperations = [];

  List<OperationRecord> get recentOperations => List.unmodifiable(_recentOperations);

  void record({
    required String summary,
    required String command,
    required int exitCode,
  }) {
    _recentOperations.insert(
      0,
      OperationRecord(
        timestamp: DateTime.now(),
        summary: summary,
        command: command,
        exitCode: exitCode,
      ),
    );
    if (_recentOperations.length > 10) {
      _recentOperations.removeRange(10, _recentOperations.length);
    }
    notifyListeners();
  }

  void clear() {
    _recentOperations.clear();
    notifyListeners();
  }
}
