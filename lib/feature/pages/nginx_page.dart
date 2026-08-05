import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/parts/nginx/cubits/nginx_cubit.dart';
import 'package:ssh_depot/feature/parts/nginx/views/nginx_view.dart';

class NginxPage extends StatefulWidget {
  const NginxPage({super.key});

  @override
  State<NginxPage> createState() => _NginxPageState();
}

class _NginxPageState extends State<NginxPage> {
  late final NginxCubit _nginxCubit;

  @override
  void initState() {
    super.initState();
    _nginxCubit = NginxCubit(commandRunner: context.read<CommandRunnerCubit>());
    _nginxCubit.load();
  }

  @override
  void dispose() {
    _nginxCubit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableProvider<NginxCubit>.value(
      value: _nginxCubit,
      child: const NginxView(),
    );
  }
}
