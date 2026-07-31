import 'package:flutter/material.dart';

import '../../../components/app_shell.dart';

class ConnectionView extends StatelessWidget {
  const ConnectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShell(selectedPath: '/', child: _ConnectionContent());
  }
}

class _ConnectionContent extends StatelessWidget {
  const _ConnectionContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('连接服务器', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          const SizedBox(
            width: 420,
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Host',
                hintText: '1.2.3.4 或 ~/.ssh/config Host 别名',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            width: 420,
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'User',
                hintText: 'root',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.link),
            label: const Text('连接测试'),
          ),
        ],
      ),
    );
  }
}
