import 'package:flutter/material.dart';

import '../components/app_shell.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedPath: '/overview',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('概览', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text('已连接服务器。MVP 阶段请从左侧进入软件包、服务、Nginx 或设置页面执行操作。'),
          ],
        ),
      ),
    );
  }
}
