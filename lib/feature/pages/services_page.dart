import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';
import 'package:ssh_depot/feature/parts/services/cubits/services_cubit.dart';
import 'package:ssh_depot/feature/parts/services/views/services_view.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  late final ServicesCubit _servicesCubit;

  @override
  void initState() {
    super.initState();
    final target = context.read<SshTarget>();
    _servicesCubit = ServicesCubit(
      commandRunner: context.read<CommandRunnerCubit>(),
      currentTarget: () => target,
    );
    unawaited(_loadAndRefresh(target));
  }

  Future<void> _loadAndRefresh(SshTarget target) async {
    await _servicesCubit.loadForTarget(target);
    if (!mounted) {
      return;
    }
    await _servicesCubit.refreshManagedServiceStatuses();
  }

  @override
  void dispose() {
    _servicesCubit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableProvider<ServicesCubit>.value(
      value: _servicesCubit,
      child: const ServicesView(),
    );
  }
}
