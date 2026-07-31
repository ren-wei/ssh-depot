import 'package:flutter/material.dart';

import '../../../components/app_shell.dart';
import '../../../components/app_scope.dart';

class ConnectionView extends StatelessWidget {
  const ConnectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShell(selectedPath: '/', child: _ConnectionContent());
  }
}

class _ConnectionContent extends StatefulWidget {
  const _ConnectionContent();

  @override
  State<_ConnectionContent> createState() => _ConnectionContentState();
}

class _ConnectionContentState extends State<_ConnectionContent> {
  final _hostController = TextEditingController();

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('连接服务器', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          SizedBox(
            width: 420,
            child: TextField(
              controller: _hostController,
              onSubmitted: controller.isRunning ? null : (_) => controller.testAndConnect(_hostController.text),
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
            onPressed: controller.isRunning ? null : () => controller.testAndConnect(_hostController.text),
            icon: const Icon(Icons.link),
            label: const Text('连接测试'),
          ),
          const SizedBox(height: 24),
          if (controller.servers.isNotEmpty) ...[
            Text('已保存服务器', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              width: 520,
              child: Column(
                children: [
                  for (final server in controller.servers)
                    ListTile(
                      leading: const Icon(Icons.dns_outlined),
                      title: Text(server.name.isEmpty ? server.host : server.name),
                      subtitle: Text(server.target),
                      trailing: FilledButton(
                        onPressed: controller.isRunning ? null : () => controller.testAndConnect(server.host),
                        child: const Text('连接'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
