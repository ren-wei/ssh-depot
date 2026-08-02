import 'package:flutter/material.dart';

import '../../../components/app_scope.dart';

class ServicesView extends StatelessWidget {
  const ServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    const services = ['nginx', 'mysql', 'redis', 'docker'];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('服务管理', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          for (final service in services)
            ListTile(
              leading: const Icon(Icons.circle_outlined),
              title: Text(service),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    onPressed: !controller.isConnected || controller.isRunning
                        ? null
                        : () => controller.serviceAction(service, 'start'),
                    icon: const Icon(Icons.play_arrow),
                    tooltip: '启动',
                  ),
                  IconButton(
                    onPressed: !controller.isConnected || controller.isRunning
                        ? null
                        : () => controller.serviceAction(service, 'stop'),
                    icon: const Icon(Icons.stop),
                    tooltip: '停止',
                  ),
                  IconButton(
                    onPressed: !controller.isConnected || controller.isRunning
                        ? null
                        : () => controller.serviceAction(service, 'restart'),
                    icon: const Icon(Icons.restart_alt),
                    tooltip: '重启',
                  ),
                  IconButton(
                    onPressed: !controller.isConnected || controller.isRunning
                        ? null
                        : () => controller.serviceAction(service, 'logs'),
                    icon: const Icon(Icons.article_outlined),
                    tooltip: '日志',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
