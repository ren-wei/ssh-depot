import 'package:flutter/material.dart';

import '../../../components/app_shell.dart';

class ServicesView extends StatelessWidget {
  const ServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    const services = ['nginx', 'mysql', 'redis', 'docker'];

    return AppShell(
      selectedPath: '/services',
      child: Padding(
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
                      onPressed: null,
                      icon: const Icon(Icons.play_arrow),
                      tooltip: '启动',
                    ),
                    IconButton(
                      onPressed: null,
                      icon: const Icon(Icons.stop),
                      tooltip: '停止',
                    ),
                    IconButton(
                      onPressed: null,
                      icon: const Icon(Icons.restart_alt),
                      tooltip: '重启',
                    ),
                    IconButton(
                      onPressed: null,
                      icon: const Icon(Icons.article_outlined),
                      tooltip: '日志',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
