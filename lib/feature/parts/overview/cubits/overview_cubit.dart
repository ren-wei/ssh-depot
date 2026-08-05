import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/overview_snapshot.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/packages/overview/overview_parser.dart';

import '../utils/overview_utils.dart';

class OverviewCubit extends ChangeNotifier {
  OverviewCubit({required CommandRunnerCubit commandRunnerCubit}) : _commandRunnerCubit = commandRunnerCubit;

  final CommandRunnerCubit _commandRunnerCubit;

  OverviewSnapshot? overviewSnapshot;
  bool overviewLoading = false;

  Future<void> refreshOverview(List<String> managedServices) async {
    overviewLoading = true;
    notifyListeners();

    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: '刷新概览',
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
