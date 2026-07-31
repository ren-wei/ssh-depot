import 'package:flutter/material.dart';

import '../../../components/app_shell.dart';

class PackagesView extends StatelessWidget {
  const PackagesView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedPath: '/packages',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('软件包管理', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            const SizedBox(
              width: 420,
              child: TextField(
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
                  onPressed: null,
                  icon: const Icon(Icons.download),
                  label: const Text('安装'),
                ),
                OutlinedButton.icon(
                  onPressed: null,
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
