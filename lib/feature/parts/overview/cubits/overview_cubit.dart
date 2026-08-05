import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/packages/command_runner/remote_command_runner.dart';
import 'package:ssh_depot/feature/parts/overview/commands/overview_commands.dart';
import 'package:ssh_depot/feature/parts/overview/parsers/overview_parser.dart';

class OverviewCubit extends ChangeNotifier {
  OverviewCubit({required RemoteCommandRunner commandRunner}) : _commandRunner = commandRunner;

  final RemoteCommandRunner _commandRunner;

  OverviewSnapshot? overviewSnapshot;
  bool overviewLoading = false;

  Future<void> refreshOverview(List<String> managedServices) async {
    overviewLoading = true;
    notifyListeners();

    final result = await _commandRunner.runCaptureCommand(
      command: overviewCommandFor(managedServices),
      timeout: const Duration(seconds: 20),
    );

    if (result != null && result.succeeded) {
      overviewSnapshot = const OverviewParser().parse(result.output);
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
