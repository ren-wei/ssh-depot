import 'package:flutter/material.dart';

import '../../../classes/server_profile.dart';
import '../../../components/app_scope.dart';
import '../../../components/app_shell.dart';
import '../../../components/depot_content.dart';

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
    return DepotContentPage(
      title: '设置',
      subtitle: '维护服务器配置与默认管理项。',
      children: [
        DepotPanel(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DepotSectionHeader(title: '服务器配置', subtitle: '保存后可在连接页快速填入。'),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                      decoration: depotInputDecoration('名称', hint: 'prod-web-01', icon: Icons.badge_outlined),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _hostController,
                      style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                      decoration: depotInputDecoration('Host', hint: '149.129.70.188', icon: Icons.dns_outlined),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _remarkController,
                      style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                      decoration: depotInputDecoration('备注', hint: '业务说明', icon: Icons.notes_outlined),
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
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('保存服务器'),
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
                title: '服务器列表',
                subtitle: controller.servers.isEmpty ? '暂无已保存服务器' : '共 ${controller.servers.length} 条配置',
              ),
              const SizedBox(height: 18),
              if (controller.servers.isEmpty)
                DepotRow(
                  child: Text(
                    '暂无服务器配置',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted),
                  ),
                )
              else
                for (final server in controller.servers) ...[
                  _ServerRow(
                    server: server,
                    selected: controller.target?.host == server.host && controller.target?.user == server.user,
                    onFill: () {
                      _nameController.text = server.name;
                      _hostController.text = server.host;
                      _remarkController.text = server.remark ?? '';
                    },
                    onDelete: () => controller.deleteServer(server),
                  ),
                  if (server != controller.servers.last) const SizedBox(height: 10),
                ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        DepotPanel(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DepotSectionHeader(title: '关注服务列表', subtitle: 'MVP 默认服务。'),
              const SizedBox(height: 18),
              DepotRow(
                child: Row(
                  children: [
                    const Icon(Icons.design_services_outlined, color: depotMuted, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        controller.managedServices.join(' / '),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: depotText, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const DepotStatusPill(label: '默认', color: depotBlue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({
    required this.server,
    required this.selected,
    required this.onFill,
    required this.onDelete,
  });

  final ServerProfile server;
  final bool selected;
  final VoidCallback onFill;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = server.name.isEmpty ? server.host : server.name;
    return DepotRow(
      child: Row(
        children: [
          DepotDot(color: selected ? depotAccent : depotBlue, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onFill,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: depotText,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${server.target}${server.remark == null ? '' : ' · ${server.remark}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 10),
            const DepotStatusPill(label: '当前', color: depotAccent),
          ],
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: depotMuted),
            tooltip: '删除',
          ),
        ],
      ),
    );
  }
}
