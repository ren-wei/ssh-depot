import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/parts/ssl/cubits/ssl_cubit.dart';
import 'package:ssh_depot/feature/parts/ssl/views/ssl_view.dart';

class SslPage extends StatefulWidget {
  const SslPage({super.key});

  @override
  State<SslPage> createState() => _SslPageState();
}

class _SslPageState extends State<SslPage> {
  late final SslCubit _sslCubit;

  @override
  void initState() {
    super.initState();
    _sslCubit = SslCubit(commandRunner: context.read<CommandRunnerCubit>());
  }

  @override
  void dispose() {
    _sslCubit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableProvider<SslCubit>.value(
      value: _sslCubit,
      child: const SslView(),
    );
  }
}
