import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/packages/command_runner/command_runner.dart';
import 'package:ssh_depot/feature/parts/overview/commands/overview_commands.dart';

class OverviewCubit extends ChangeNotifier {
  OverviewCubit({required CommandRunner commandRunner}) : _commandRunner = commandRunner;

  final CommandRunner _commandRunner;

  OverviewSnapshot? overviewSnapshot;
  bool overviewLoading = false;

  Future<void> refreshOverview(List<String> managedServices) async {
    overviewLoading = true;
    notifyListeners();

    final snapshot = await _commandRunner.runCaptureCommand(
      command: overviewCommandFor(managedServices),
      timeout: const Duration(seconds: 20),
    );

    if (snapshot != null) {
      overviewSnapshot = snapshot;
    }
    overviewLoading = false;
    notifyListeners();
  }

  void clear() {
    overviewSnapshot = null;
    overviewLoading = false;
    notifyListeners();
  }
}
