import 'package:flutter/material.dart';

import '../../../components/app_scope.dart';
import '../../../components/app_shell.dart';
import '../../../components/depot_content.dart';
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
    final disabled = !controller.isConnected || controller.isRunning;
    return DepotContentPage(
      title: 'Nginx 管理',
      subtitle: '管理站点启用状态、生成配置并写入远端 Nginx。',
      actions: [
        DepotStatusPill(
          label: controller.isRunning ? '执行中' : (controller.isConnected ? '就绪' : '未连接'),
          color: controller.isConnected ? depotAccent : depotYellow,
        ),
      ],
      children: [
        DepotPanel(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DepotSectionHeader(title: '站点操作', subtitle: '刷新站点、检查语法或 reload 服务。'),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: disabled ? null : controller.listNginxSites,
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text('刷新站点'),
                    style: depotFilledButtonStyle(),
                  ),
                  OutlinedButton.icon(
                    onPressed: disabled ? null : controller.testNginx,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('语法检查'),
                    style: depotOutlinedButtonStyle(),
                  ),
                  OutlinedButton.icon(
                    onPressed: disabled ? null : controller.reloadNginx,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reload'),
                    style: depotOutlinedButtonStyle(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        DepotPanel(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DepotSectionHeader(title: '站点链接', subtitle: '操作 sites-available 与 sites-enabled。'),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _siteController,
                      style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                      decoration: depotInputDecoration('站点名', hint: 'example.com', icon: Icons.language),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: disabled ? null : () => controller.enableNginxSite(_siteController.text),
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('启用'),
                    style: depotOutlinedButtonStyle(),
                  ),
                  OutlinedButton.icon(
                    onPressed: disabled ? null : () => controller.disableNginxSite(_siteController.text),
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('禁用'),
                    style: depotOutlinedButtonStyle(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        DepotPanel(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DepotSectionHeader(title: '模板生成', subtitle: '生成后可在下方预览区微调。'),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String>(
                      initialValue: _templateId,
                      dropdownColor: depotPanel,
                      style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                      decoration: depotInputDecoration('模板', icon: Icons.description_outlined),
                      items: [
                        for (final template in controller.nginxTemplates)
                          DropdownMenuItem(value: template.id, child: Text(template.name)),
                      ],
                      onChanged: (value) => setState(() => _templateId = value ?? _templateId),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _domainController,
                      style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                      decoration: depotInputDecoration('域名', hint: 'example.com', icon: Icons.public),
                    ),
                  ),
                  if (_templateId == 'static_site')
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _rootPathController,
                        style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                        decoration: depotInputDecoration('网站根目录', hint: '/var/www/html', icon: Icons.folder_outlined),
                      ),
                    ),
                  if (_templateId == 'reverse_proxy') ...[
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _upstreamHostController,
                        style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                        decoration: depotInputDecoration('后端地址', hint: '127.0.0.1', icon: Icons.hub_outlined),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: _upstreamPortController,
                        style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                        decoration: depotInputDecoration('端口', hint: '3000', icon: Icons.tag),
                      ),
                    ),
                  ],
                  if (_templateId == 'static_site')
                    FilterChip(
                      selected: _enableLogs,
                      onSelected: (value) => setState(() => _enableLogs = value),
                      avatar: const Icon(Icons.notes, size: 16),
                      label: const Text('开启日志'),
                      selectedColor: depotAccent,
                      backgroundColor: depotPanelAlt.withValues(alpha: 0.42),
                      side: const BorderSide(color: depotLineDim),
                      labelStyle: TextStyle(
                        color: _enableLogs ? const Color(0xff06311f) : depotText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: () => _renderTemplate(controller),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('生成配置'),
                    style: depotFilledButtonStyle(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        DepotPanel(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DepotSectionHeader(
                title: '配置预览',
                subtitle: '写入前可手动微调。',
                trailing: FilledButton.icon(
                  onPressed: disabled
                      ? null
                      : () => controller.writeNginxSite(
                            siteName: _siteController.text,
                            config: _configController.text,
                          ),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('写入并 Reload'),
                  style: depotFilledButtonStyle(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 360,
                child: TextField(
                  controller: _configController,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  style: const TextStyle(
                    color: Color(0xffd6eadf),
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.45,
                  ),
                  decoration: depotInputDecoration('配置内容', icon: Icons.code).copyWith(alignLabelWithHint: true),
                ),
              ),
            ],
          ),
        ),
      ],
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
