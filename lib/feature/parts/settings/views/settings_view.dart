import 'package:flutter/material.dart';

import '../../../components/app_shell.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedPath: '/settings',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('设置', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.dns_outlined),
              title: Text('服务器管理'),
              subtitle: Text('保存 root@host、名称和备注到 ~/.myctl/servers.yaml'),
            ),
            const ListTile(
              leading: Icon(Icons.design_services_outlined),
              title: Text('关注服务列表'),
              subtitle: Text('默认 nginx / mysql / redis / docker'),
            ),
          ],
        ),
      ),
    );
  }
}
