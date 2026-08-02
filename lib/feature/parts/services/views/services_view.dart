import 'package:flutter/material.dart';

import '../../../classes/overview_snapshot.dart';
import '../../../components/app_scope.dart';
import '../../../components/app_shell.dart';
import '../../../components/depot_content.dart';
import '../../../cubits/app_controller.dart';

class ServicesView extends StatefulWidget {
  const ServicesView({super.key});

  @override
  State<ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends State<ServicesView> {
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final services = controller.managedServices;
    final disabled = !controller.isConnected || controller.isRunning;
    final serviceSnapshots = {
      for (final service in controller.overviewSnapshot?.services ?? const <ServiceSnapshot>[]) service.name: service,
      ...controller.serviceSnapshots,
    };

    return DepotContentPage(
      title: '服务管理',
      subtitle: '通过当前 SSH 连接执行 systemctl 与 journalctl 操作。',
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
              DepotSectionHeader(
                title: '服务列表',
                subtitle: services.length == 1 ? '默认服务 nginx，可手动添加更多服务。' : '共 ${services.length} 个服务。',
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _showAddServiceDialog(controller),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加服务'),
                  style: depotFilledButtonStyle(),
                ),
              ),
              const SizedBox(height: 18),
              DepotRow(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('服务', style: depotMutedText(context))),
                    Expanded(flex: 2, child: Text('状态', style: depotMutedText(context))),
                    Expanded(flex: 5, child: Text('操作', textAlign: TextAlign.right, style: depotMutedText(context))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              for (final service in services) ...[
                _ServiceControlRow(
                  service: service,
                  snapshot: serviceSnapshots[service],
                  disabled: disabled,
                  onStart: () => controller.serviceAction(service, 'start'),
                  onStop: () => controller.serviceAction(service, 'stop'),
                  onRestart: () => controller.serviceAction(service, 'restart'),
                  onLogs: () => controller.fetchServiceLogs(service),
                  onRemove: () => _confirmRemoveService(controller, service),
                ),
                if (service != services.last) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        _ServiceLogsPanel(
          service: controller.serviceLogsService,
          output: controller.serviceLogsOutput,
          isRunning: controller.isRunning,
        ),
      ],
    );
  }

  Future<void> _showAddServiceDialog(AppController controller) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _AddServiceDialog(controller: controller),
    );
  }

  Future<void> _confirmRemoveService(AppController controller, String service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: depotPanel,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: depotLine),
          ),
          title: Text(
            '移除服务',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: depotText, fontWeight: FontWeight.w900),
          ),
          content: Text(
            '确认从服务管理中移除 $service？',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted, fontWeight: FontWeight.w700),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: depotOutlinedButtonStyle(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: depotFilledButtonStyle(),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await controller.removeManagedService(service);
    }
  }
}

class _AddServiceDialog extends StatefulWidget {
  const _AddServiceDialog({required this.controller});

  final AppController controller;

  @override
  State<_AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<_AddServiceDialog> {
  final _queryController = TextEditingController();
  late Future<List<String>> _servicesFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _servicesFuture = widget.controller.searchRemoteServices();
    _queryController.addListener(() {
      setState(() => _query = _queryController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: depotPanel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: depotLine),
      ),
      title: Text(
        '添加服务',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: depotText, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 560,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
              decoration: depotInputDecoration('服务名称', hint: '输入关键词搜索远端服务', icon: Icons.search),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _servicesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  final services = snapshot.data ?? const <String>[];
                  final filteredServices = [
                    for (final service in services)
                      if (_query.isEmpty || service.toLowerCase().contains(_query)) service,
                  ];
                  if (filteredServices.isEmpty) {
                    return Center(
                      child: Text(
                        services.isEmpty ? '未找到远端服务' : '没有匹配的服务',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filteredServices.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final service = filteredServices[index];
                      final added = widget.controller.managedServices.contains(service);
                      return DepotRow(
                        height: 54,
                        child: Row(
                          children: [
                            const DepotDot(color: depotBlue, size: 14),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                service,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: depotText,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (added)
                              const DepotStatusPill(label: '已添加', color: depotMuted)
                            else
                              SizedBox(
                                width: 76,
                                child: FilledButton(
                                  onPressed: () async {
                                    await widget.controller.addManagedService(service);
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  style: depotFilledButtonStyle().copyWith(
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                  ),
                                  child: const Text('添加'),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: depotOutlinedButtonStyle(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class _ServiceControlRow extends StatelessWidget {
  const _ServiceControlRow({
    required this.service,
    required this.snapshot,
    required this.disabled,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onLogs,
    required this.onRemove,
  });

  final String service;
  final ServiceSnapshot? snapshot;
  final bool disabled;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onLogs;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final status = snapshot?.status ?? ServiceStatus.unknown;
    final statusColor = switch (status) {
      ServiceStatus.active => depotAccent,
      ServiceStatus.failed => depotRed,
      ServiceStatus.inactive => depotMuted,
      ServiceStatus.unknown => depotYellow,
    };
    return DepotRow(
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                DepotDot(color: statusColor, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    service,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: depotText,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: DepotStatusPill(label: status.label, color: statusColor),
            ),
          ),
          Expanded(
            flex: 5,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: _actionsForStatus(status),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: depotMuted, size: 18),
            tooltip: '移除服务',
          ),
        ],
      ),
    );
  }

  List<Widget> _actionsForStatus(ServiceStatus status) {
    final logs = _MiniAction(label: '查看日志', icon: Icons.notes_outlined, disabled: disabled, onPressed: onLogs);
    return switch (status) {
      ServiceStatus.active => [
          _MiniAction(label: '停止', icon: Icons.stop_circle_outlined, disabled: disabled, onPressed: onStop),
          _MiniAction(label: '重启', icon: Icons.restart_alt, disabled: disabled, onPressed: onRestart),
          logs,
        ],
      ServiceStatus.inactive || ServiceStatus.failed => [
          _MiniAction(label: '启动', icon: Icons.play_arrow, disabled: disabled, onPressed: onStart),
          logs,
        ],
      ServiceStatus.unknown => [
          _MiniAction(label: '启动', icon: Icons.play_arrow, disabled: disabled, onPressed: onStart),
          _MiniAction(label: '停止', icon: Icons.stop_circle_outlined, disabled: disabled, onPressed: onStop),
          _MiniAction(label: '重启', icon: Icons.restart_alt, disabled: disabled, onPressed: onRestart),
          logs,
        ],
    };
  }
}

class _ServiceLogsPanel extends StatelessWidget {
  const _ServiceLogsPanel({
    required this.service,
    required this.output,
    required this.isRunning,
  });

  final String? service;
  final String output;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return DepotPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: depotLineDim))),
            child: Row(
              children: [
                const Icon(Icons.notes_outlined, size: 18, color: depotMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    service == null ? '服务日志' : '$service 日志',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: depotText,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (isRunning && service != null)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          SizedBox(
            height: 300,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Align(
                alignment: Alignment.topLeft,
                child: SelectableText(
                  output.isEmpty ? '点击服务行的“查看日志”后显示输出。' : output,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: output.isEmpty ? depotMuted : const Color(0xffd6eadf),
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: disabled ? null : onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: depotText,
        disabledForegroundColor: depotMuted.withValues(alpha: 0.5),
        side: const BorderSide(color: depotLine),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
