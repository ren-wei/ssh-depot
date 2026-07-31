import 'package:flutter/material.dart';

import '../../../components/app_shell.dart';

class NginxView extends StatelessWidget {
  const NginxView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedPath: '/nginx',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nginx 管理', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.add),
                  label: const Text('新建站点'),
                ),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check),
                  label: const Text('语法检查'),
                ),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Expanded(child: Center(child: Text('站点列表将在连接服务器后显示'))),
          ],
        ),
      ),
    );
  }
}
