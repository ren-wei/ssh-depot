import 'package:flutter/material.dart';

import '../components/app_scope.dart';
import '../components/app_shell.dart';
import '../components/depot_scrollbar.dart';
import '../classes/overview_snapshot.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final _scrollController = ScrollController();
  bool _requestedInitialRefresh = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (!_requestedInitialRefresh && controller.isConnected && controller.overviewSnapshot == null) {
      _requestedInitialRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          controller.refreshOverview();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final target = controller.target;
    final snapshot = controller.overviewSnapshot;

    return ColoredBox(
      color: Colors.transparent,
      child: DepotScrollbar(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          children: [
            _HeroPanel(
              targetLabel: target?.address ?? '未连接',
              snapshot: snapshot,
              isRunning: controller.overviewLoading || controller.isRunning,
              onRefresh: controller.overviewLoading || controller.isRunning ? null : controller.refreshOverview,
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'CPU',
                    value: _percent(snapshot?.cpuPercent),
                    source: '/proc/stat',
                    color: depotAccent,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _MetricCard(
                    label: '内存',
                    value: _percent(snapshot?.memoryPercent),
                    source: 'free -m',
                    color: depotBlue,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _MetricCard(
                    label: '磁盘',
                    value: _percent(snapshot?.diskPercent),
                    source: 'df -P /',
                    color: depotYellow,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _MetricCard(
                    label: '关注服务数',
                    value: '${controller.managedServices.length}',
                    source: '服务页关注项',
                    color: depotRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _ServiceStatusPanel(
                    isRunning: controller.isRunning,
                    managedServices: controller.managedServices,
                    services: snapshot?.services ?? const [],
                    onServiceAction: controller.serviceAction,
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(child: _RecentOpsPanel(operations: controller.recentOperations)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _percent(int? value) => value == null ? '--' : '$value%';

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.targetLabel,
    required this.snapshot,
    required this.isRunning,
    required this.onRefresh,
  });

  final String targetLabel;
  final OverviewSnapshot? snapshot;
  final bool isRunning;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(42, 34, 42, 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('概览',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: depotText, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  '已连接 1 台主机 · ${snapshot == null ? '等待刷新运行状态' : '运行状态已更新'}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: depotText, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Text(
                  '集中查看系统资源、服务状态和最近操作记录。点击刷新后会通过当前 SSH 连接获取最新数据。',
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: depotTerminal,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: depotLineDim),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _Dot(color: depotAccent),
                      const SizedBox(width: 10),
                      Text(
                        '$targetLabel · ${snapshot?.distribution ?? '--'} · ${snapshot?.uptime ?? '--'}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: depotText, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          FilledButton.icon(
            onPressed: onRefresh,
            icon: isRunning
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.radio_button_checked, size: 18),
            label: Text(isRunning ? '刷新中' : '手动刷新'),
            style: FilledButton.styleFrom(
              backgroundColor: depotPanel,
              foregroundColor: depotText,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: const BorderSide(color: depotLine),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.source,
    required this.color,
  });

  final String label;
  final String value;
  final String source;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      height: 126,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Dot(color: color, size: 14),
              const SizedBox(width: 9),
              Text(label,
                  style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(color: depotText, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style:
                  Theme.of(context).textTheme.headlineSmall?.copyWith(color: depotText, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text(source,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ServiceStatusPanel extends StatelessWidget {
  const _ServiceStatusPanel({
    required this.isRunning,
    required this.managedServices,
    required this.services,
    required this.onServiceAction,
  });

  final bool isRunning;
  final List<String> managedServices;
  final List<ServiceSnapshot> services;
  final Future<void> Function(String service, String action) onServiceAction;

  @override
  Widget build(BuildContext context) {
    final visibleServices = services.isEmpty
        ? [
            for (final service in managedServices)
              ServiceSnapshot(name: service, status: ServiceStatus.unknown, enabled: null),
          ]
        : services;
    return _Panel(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('关键服务状态速览',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: depotText, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('展示已关注服务的运行状态，可在服务页添加或移除关注项。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted)),
          const SizedBox(height: 18),
          const _ServiceHeader(),
          const SizedBox(height: 10),
          for (final service in visibleServices) ...[
            _ServiceRow(
              service: service,
              disabled: isRunning,
              onStop: () => onServiceAction(service.name, 'stop'),
              onRestart: () => onServiceAction(service.name, 'restart'),
              onLogs: () => onServiceAction(service.name, 'logs'),
            ),
            if (service != visibleServices.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ServiceHeader extends StatelessWidget {
  const _ServiceHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: depotPanelAlt.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: depotLineDim),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('服务', style: _mutedText(context))),
          Expanded(flex: 2, child: Text('状态', style: _mutedText(context))),
          Expanded(flex: 3, child: Text('操作', style: _mutedText(context))),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.disabled,
    required this.onStop,
    required this.onRestart,
    required this.onLogs,
  });

  final ServiceSnapshot service;
  final bool disabled;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onLogs;

  @override
  Widget build(BuildContext context) {
    final color = switch (service.status) {
      ServiceStatus.active => depotAccent,
      ServiceStatus.failed => depotRed,
      ServiceStatus.inactive => depotMuted,
      ServiceStatus.unknown => depotYellow,
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: depotPanelAlt.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: depotLineDim),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _Dot(color: color, size: 18),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: depotText, fontWeight: FontWeight.w800)),
                    Text(
                      service.enabled == null ? '自启未知' : (service.enabled! ? '已设为自启' : '未设自启'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  service.status.label,
                  style: const TextStyle(color: Color(0xff06311f), fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _MiniAction(label: '停止', icon: Icons.stop_circle_outlined, disabled: disabled, onPressed: onStop),
                _MiniAction(label: '重启', icon: Icons.restart_alt, disabled: disabled, onPressed: onRestart),
                _MiniAction(label: '日志', icon: Icons.notes_outlined, disabled: disabled, onPressed: onLogs),
              ],
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
      ),
    );
  }
}

class _RecentOpsPanel extends StatelessWidget {
  const _RecentOpsPanel({required this.operations});

  final List<OperationRecord> operations;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最近操作记录',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: depotText, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('自动记录最近 5-10 条命令及结果', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted)),
          const SizedBox(height: 18),
          if (operations.isEmpty)
            Text('暂无操作记录', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted))
          else
            for (final operation in operations.take(5)) ...[
              _RecentOpRow(operation: operation),
              if (operation != operations.take(5).last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _RecentOpRow extends StatelessWidget {
  const _RecentOpRow({required this.operation});

  final OperationRecord operation;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: depotPanelAlt.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: depotLineDim),
      ),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(_timeLabel(operation.timestamp), style: _mutedText(context))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              operation.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: depotText, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            operation.succeeded ? '成功' : '失败',
            style: TextStyle(
                color: operation.succeeded ? depotAccent : depotRed, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.height,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: depotPanel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: depotLine.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 1)],
      ),
    );
  }
}

TextStyle _mutedText(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall!.copyWith(color: depotMuted, fontWeight: FontWeight.w700);
}
