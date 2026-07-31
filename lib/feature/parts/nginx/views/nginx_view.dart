import 'package:flutter/material.dart';

import '../../../components/app_shell.dart';
import '../../../components/app_scope.dart';
import '../../../cubits/app_controller.dart';

class NginxView extends StatefulWidget {
  const NginxView({super.key});

  @override
  State<NginxView> createState() => _NginxViewState();
}

class _NginxViewState extends State<NginxView> {
  final _siteController = TextEditingController();
  final _domainController = TextEditingController();
  final _rootPathController = TextEditingController(text: '/var/www/html');
  final _upstreamHostController = TextEditingController(text: '127.0.0.1');
  final _upstreamPortController = TextEditingController(text: '3000');
  final _configController = TextEditingController();
  String _templateId = 'static_site';
  bool _enableLogs = true;

  @override
  void dispose() {
    _siteController.dispose();
    _domainController.dispose();
    _rootPathController.dispose();
    _upstreamHostController.dispose();
    _upstreamPortController.dispose();
    _configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
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
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: !controller.isConnected || controller.isRunning ? null : controller.listNginxSites,
                  icon: const Icon(Icons.list),
                  label: const Text('刷新站点'),
                ),
                OutlinedButton.icon(
                  onPressed: !controller.isConnected || controller.isRunning ? null : controller.testNginx,
                  icon: const Icon(Icons.check),
                  label: const Text('语法检查'),
                ),
                OutlinedButton.icon(
                  onPressed: !controller.isConnected || controller.isRunning ? null : controller.reloadNginx,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _siteController,
                    decoration: const InputDecoration(
                      labelText: '站点名',
                      hintText: 'example.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: !controller.isConnected || controller.isRunning
                      ? null
                      : () => controller.enableNginxSite(_siteController.text),
                  icon: const Icon(Icons.link),
                  label: const Text('启用'),
                ),
                OutlinedButton.icon(
                  onPressed: !controller.isConnected || controller.isRunning
                      ? null
                      : () => controller.disableNginxSite(_siteController.text),
                  icon: const Icon(Icons.link_off),
                  label: const Text('禁用'),
                ),
              ],
            ),
            const Divider(height: 36),
            Text('模板生成', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _templateId,
                    decoration: const InputDecoration(labelText: '模板', border: OutlineInputBorder()),
                    items: [
                      for (final template in controller.nginxTemplates)
                        DropdownMenuItem(value: template.id, child: Text(template.name)),
                    ],
                    onChanged: (value) => setState(() => _templateId = value ?? _templateId),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _domainController,
                    decoration: const InputDecoration(labelText: '域名', border: OutlineInputBorder()),
                  ),
                ),
                if (_templateId == 'static_site')
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _rootPathController,
                      decoration: const InputDecoration(labelText: '网站根目录', border: OutlineInputBorder()),
                    ),
                  ),
                if (_templateId == 'reverse_proxy') ...[
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _upstreamHostController,
                      decoration: const InputDecoration(labelText: '后端地址', border: OutlineInputBorder()),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _upstreamPortController,
                      decoration: const InputDecoration(labelText: '后端端口', border: OutlineInputBorder()),
                    ),
                  ),
                ],
                if (_templateId == 'static_site')
                  FilterChip(
                    selected: _enableLogs,
                    onSelected: (value) => setState(() => _enableLogs = value),
                    label: const Text('开启日志'),
                  ),
                FilledButton.icon(
                  onPressed: () => _renderTemplate(controller),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('生成配置'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _configController,
                expands: true,
                maxLines: null,
                minLines: null,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: '配置预览，可手动微调',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: !controller.isConnected || controller.isRunning
                    ? null
                    : () => controller.writeNginxSite(
                          siteName: _siteController.text,
                          config: _configController.text,
                        ),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('写入并 Reload'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _renderTemplate(AppController controller) {
    final domain = _domainController.text.trim();
    if (_siteController.text.trim().isEmpty && domain.isNotEmpty) {
      _siteController.text = domain;
    }
    _configController.text = controller.renderNginxTemplate(_templateId, {
      'domain': domain,
      'root_path': _rootPathController.text.trim(),
      'enable_logs': _enableLogs,
      'upstream_host': _upstreamHostController.text.trim(),
      'upstream_port': _upstreamPortController.text.trim(),
    });
  }
}
