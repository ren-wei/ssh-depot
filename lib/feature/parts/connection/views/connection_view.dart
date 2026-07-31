import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_scope.dart';
import '../../../cubits/app_controller.dart';

class ConnectionView extends StatelessWidget {
  const ConnectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SingleChildScrollView(child: _ConnectionContent()),
      ),
    );
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('登录服务器', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('通过 SSH 连接 root 用户后进入操作面板', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            SizedBox(
              width: 420,
              child: TextField(
                controller: _hostController,
                onSubmitted: controller.isRunning ? null : (_) => _login(controller),
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
              onPressed: controller.isRunning ? null : () => _login(controller),
              icon: const Icon(Icons.link),
              label: Text(controller.isRunning ? '连接中' : '登录'),
            ),
            const SizedBox(height: 24),
            if (controller.servers.isNotEmpty) ...[
              Text('历史服务器', style: Theme.of(context).textTheme.titleMedium),
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
                          onPressed: controller.isRunning ? null : () => _quickLogin(controller, server.host),
                          child: const Text('快速登录'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _login(AppController controller) async {
    await controller.testAndConnect(_hostController.text);
    if (!mounted || !controller.isConnected) {
      return;
    }
    context.go('/overview');
  }

  Future<void> _quickLogin(AppController controller, String host) async {
    _hostController.text = host;
    await _login(controller);
  }
}
