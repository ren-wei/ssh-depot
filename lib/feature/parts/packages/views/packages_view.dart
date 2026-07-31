import 'package:flutter/material.dart';

import '../../../components/app_shell.dart';
import '../../../components/app_scope.dart';

class PackagesView extends StatefulWidget {
  const PackagesView({super.key});

  @override
  State<PackagesView> createState() => _PackagesViewState();
}

class _PackagesViewState extends State<PackagesView> {
  final _packageController = TextEditingController();

  @override
  void dispose() {
    _packageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppShell(
      selectedPath: '/packages',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('软件包管理', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            SizedBox(
              width: 420,
              child: TextField(
                controller: _packageController,
                decoration: InputDecoration(
                  labelText: '包名',
                  hintText: 'nginx',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: !controller.isConnected || controller.isRunning
                      ? null
                      : () => controller.installPackage(_packageController.text),
                  icon: const Icon(Icons.download),
                  label: const Text('安装'),
                ),
                OutlinedButton.icon(
                  onPressed: !controller.isConnected || controller.isRunning
                      ? null
                      : () => controller.removePackage(_packageController.text),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('卸载'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
