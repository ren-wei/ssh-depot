import 'package:flutter/material.dart';

import '../../../components/app_scope.dart';
import '../../../components/app_shell.dart';
import '../../../components/depot_content.dart';

class PackagesView extends StatefulWidget {
  const PackagesView({super.key});

  @override
  State<PackagesView> createState() => _PackagesViewState();
}

class _PackagesViewState extends State<PackagesView> {
  final _packageController = TextEditingController();

  @override
  void dispose() {
    _packageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final disabled = !controller.isConnected || controller.isRunning;
    return DepotContentPage(
      title: '软件包管理',
      subtitle: '使用当前 SSH 连接执行 apt 安装、卸载和常用包快捷输入。',
      children: [
        DepotPanel(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DepotSectionHeader(
                title: '包操作',
                subtitle: controller.isConnected ? '目标主机已连接' : '请先连接服务器',
                trailing: DepotStatusPill(
                  label: controller.isRunning ? '执行中' : (controller.isConnected ? '就绪' : '未连接'),
                  color: controller.isConnected ? depotAccent : depotYellow,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _packageController,
                      style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                      decoration: depotInputDecoration('包名', hint: 'nginx', icon: Icons.inventory_2_outlined),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: disabled ? null : () => controller.installPackage(_packageController.text),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('安装'),
                    style: depotFilledButtonStyle(),
                  ),
                  OutlinedButton.icon(
                    onPressed: disabled ? null : () => controller.removePackage(_packageController.text),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('卸载'),
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
              const DepotSectionHeader(title: '执行方式', subtitle: '命令输出会进入底部终端面板。'),
              const SizedBox(height: 16),
              DepotRow(
                child: Row(
                  children: [
                    const DepotDot(color: depotBlue, size: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '安装: apt update && apt install -y <包名>',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: depotText, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              DepotRow(
                child: Row(
                  children: [
                    const DepotDot(color: depotRed, size: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '卸载: apt remove -y <包名>',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: depotText, fontWeight: FontWeight.w800),
                      ),
                    ),
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
