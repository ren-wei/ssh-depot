import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';
import 'package:ssh_depot/feature/parts/overview/cubits/overview_cubit.dart';
import 'package:ssh_depot/feature/parts/overview/views/overview_view.dart';
import 'package:ssh_depot/feature/parts/services/cubits/services_cubit.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late final OverviewCubit _overviewCubit;
  late final ServicesCubit _servicesCubit;

  @override
  void initState() {
    super.initState();
    final commandRunnerCubit = context.read<CommandRunnerCubit>();
    final target = context.read<SshTarget>();
    _overviewCubit = OverviewCubit(commandRunner: commandRunnerCubit);
    _servicesCubit = ServicesCubit(
      commandRunner: commandRunnerCubit,
      currentTarget: () => target,
    );
    _servicesCubit.loadForTarget(target);
  }

  @override
  void dispose() {
    _overviewCubit.dispose();
    _servicesCubit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ListenableProvider<OverviewCubit>.value(value: _overviewCubit),
        ListenableProvider<ServicesCubit>.value(value: _servicesCubit),
      ],
      child: const OverviewView(),
    );
  }
}
