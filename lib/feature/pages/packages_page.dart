import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/parts/packages/cubits/packages_cubit.dart';
import 'package:ssh_depot/feature/parts/packages/views/packages_view.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key});

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  late final PackagesCubit _packagesCubit;

  @override
  void initState() {
    super.initState();
    _packagesCubit = PackagesCubit(commandRunner: context.read<CommandRunnerCubit>());
  }

  @override
  void dispose() {
    _packagesCubit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableProvider<PackagesCubit>.value(
      value: _packagesCubit,
      child: const PackagesView(),
    );
  }
}
