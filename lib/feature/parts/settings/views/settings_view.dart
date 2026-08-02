import 'package:flutter/material.dart';

import '../../../classes/server_profile.dart';
import '../../../components/app_scope.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _remarkController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _remarkController.dispose();
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
          Text('设置', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder()),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(labelText: 'Host', border: OutlineInputBorder()),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _remarkController,
                  decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder()),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  final host = _hostController.text.trim();
                  if (host.isEmpty) {
                    return;
                  }
                  controller.saveServer(
                    ServerProfile(
                      name: _nameController.text.trim().isEmpty ? host : _nameController.text.trim(),
                      host: host,
                      remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim(),
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存服务器'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('服务器列表', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final server in controller.servers)
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: Text(server.name.isEmpty ? server.host : server.name),
              subtitle: Text('${server.target}${server.remark == null ? '' : ' · ${server.remark}'}'),
              trailing: IconButton(
                onPressed: () => controller.deleteServer(server),
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除',
              ),
            ),
          const ListTile(
            leading: Icon(Icons.design_services_outlined),
            title: Text('关注服务列表'),
            subtitle: Text('MVP 默认 nginx / mysql / redis / docker'),
          ),
        ],
      ),
    );
  }
}
