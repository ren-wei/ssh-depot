import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../cubits/app_controller.dart';
import '../parts/connection/views/connection_view.dart';
import 'app_scope.dart';
import 'depot_scrollbar.dart';

const depotBg = Color(0xff02110b);
const depotPanel = Color(0xff0b2418);
const depotPanelAlt = Color(0xff103520);
const depotLine = Color(0xff1d5940);
const depotLineDim = Color(0xff16432f);
const depotText = Color(0xffeef8f2);
const depotMuted = Color(0xff9db4a8);
const depotAccent = Color(0xff3fe09a);
const depotBlue = Color(0xff55bde8);
const depotYellow = Color(0xffffcf63);
const depotRed = Color(0xffff6d92);
const depotTerminal = Color(0xff06170f);

class AppShell extends StatelessWidget {
  const AppShell({required this.selectedPath, required this.child, super.key});

  final String selectedPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndexForPath(selectedPath);
    final controller = AppScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final target = controller.target;
        if (target == null) {
          return const ConnectionView();
        }

        return Scaffold(
          backgroundColor: depotBg,
          body: SafeArea(
            child: Stack(
              children: [
                const _GlowBackdrop(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          _TopBar(
                            target: target.address,
                            isRunning: controller.isRunning,
                            onCancel: controller.cancelRunning,
                            onDisconnect: controller.disconnect,
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Sidebar(
                                  selectedIndex: selectedIndex,
                                  statusLine: controller.statusLine,
                                  onSelect: (index) {
                                    final item = _items[index];
                                    if (item.path == null) {
                                      return;
                                    }
                                    context.go(item.path!);
                                  },
                                ),
                                const SizedBox(width: 22),
                                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(26), child: child)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _TerminalStatusBar(),
                        ],
                      ),
                      if (controller.terminalExpanded)
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 70,
                          child: _TerminalPanel(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

int _selectedIndexForPath(String path) {
  final index = _items.indexWhere((item) => item.path == path);
  return index < 0 ? 0 : index;
}

class _ShellItem {
  const _ShellItem({
    required this.label,
    required this.icon,
    required this.subtitle,
    this.path,
  });

  final String? path;
  final String label;
  final String subtitle;
  final IconData icon;
}

const _items = [
  _ShellItem(path: '/overview', label: '概览', subtitle: '连接后首页', icon: Icons.dashboard_outlined),
  _ShellItem(path: '/packages', label: '软件包', subtitle: 'apt 安装/卸载', icon: Icons.inventory_2_outlined),
  _ShellItem(path: '/services', label: '服务', subtitle: '启停/重启/状态', icon: Icons.toggle_on_outlined),
  _ShellItem(path: '/nginx', label: '网站管理', subtitle: '站点配置', icon: Icons.account_tree_outlined),
  _ShellItem(label: 'SSL', subtitle: '证书管理', icon: Icons.key_outlined),
  _ShellItem(label: '文件', subtitle: '目录与编辑', icon: Icons.folder_outlined),
  _ShellItem(label: '日志', subtitle: '常见日志源', icon: Icons.notes_outlined),
  _ShellItem(label: 'Cron', subtitle: '定时任务', icon: Icons.schedule_outlined),
  _ShellItem(path: '/settings', label: '设置', subtitle: '服务器与偏好', icon: Icons.settings_outlined),
];

class _GlowBackdrop extends StatelessWidget {
  const _GlowBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.62, -0.58),
          radius: 1.15,
          colors: [Color(0xff1c8d51), Color(0xff073220), depotBg],
          stops: [0, 0.44, 1],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.target,
    required this.isRunning,
    required this.onCancel,
    required this.onDisconnect,
  });

  final String target;
  final bool isRunning;
  final VoidCallback onCancel;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return _FramePanel(
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: depotAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: depotAccent.withValues(alpha: 0.36)),
            ),
            child: const Center(child: _StatusDot(size: 24)),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('myctl',
                  style:
                      Theme.of(context).textTheme.titleLarge?.copyWith(color: depotText, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(target,
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted, fontWeight: FontWeight.w600)),
            ],
          ),
          const Spacer(),
          if (isRunning) ...[
            _PillButton(
              label: '取消',
              icon: Icons.stop_circle_outlined,
              onPressed: onCancel,
            ),
            const SizedBox(width: 10),
          ],
          _PillButton(label: '断开', icon: Icons.link_off, onPressed: onDisconnect),
        ],
      ),
    );
  }
}

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.statusLine,
    required this.onSelect,
  });

  final int selectedIndex;
  final String statusLine;
  final ValueChanged<int> onSelect;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FramePanel(
      width: 280,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('功能导航',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Expanded(
            child: DepotScrollbar(
              controller: _scrollController,
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemCount: _items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _NavTile(
                    item: _items[index],
                    selected: widget.selectedIndex == index,
                    onTap: () => widget.onSelect(index),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: depotPanelAlt.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: depotLineDim),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最近操作',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: depotMuted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(widget.statusLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.onTap});

  final _ShellItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = item.path != null;
    final foreground = enabled ? depotText : depotMuted.withValues(alpha: 0.62);
    final subtitleColor = enabled ? depotMuted : depotMuted.withValues(alpha: 0.48);
    return Material(
      color: selected ? depotAccent.withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? depotAccent.withValues(alpha: 0.45) : depotLineDim),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? depotAccent : depotPanel,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: depotLineDim),
                ),
                child: Icon(item.icon, size: 22, color: selected ? const Color(0xff06311f) : foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: foreground, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: subtitleColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TerminalStatusBar extends StatelessWidget {
  const _TerminalStatusBar();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final failed = controller.statusLine.startsWith('✗');
    final succeeded = controller.statusLine.startsWith('✓');
    final statusText = _statusSummaryText(controller.statusLine);
    return _FramePanel(
      height: 58,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: depotText, fontFamily: 'monospace', fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          if (failed || succeeded) ...[
            Icon(failed ? Icons.close : Icons.check, color: failed ? depotRed : depotAccent, size: 18),
            const SizedBox(width: 6),
            Text(
              failed ? '失败' : '成功',
              style: TextStyle(color: failed ? depotRed : depotAccent, fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(width: 18),
          IconButton(
            onPressed: controller.toggleTerminal,
            icon: AnimatedRotation(
              turns: controller.terminalExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              child: const Icon(Icons.keyboard_arrow_up, color: depotText),
            ),
            tooltip: controller.terminalExpanded ? '收起终端' : '展开终端',
          ),
        ],
      ),
    );
  }

  String _statusSummaryText(String statusLine) {
    final value = statusLine.trim();
    for (final suffix in const [' 成功', ' 失败']) {
      if (value.endsWith(suffix)) {
        return value.substring(0, value.length - suffix.length);
      }
    }
    return value;
  }
}

class _TerminalPanel extends StatefulWidget {
  const _TerminalPanel();

  @override
  State<_TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<_TerminalPanel> {
  final _scrollController = ScrollController();
  AppController? _controller;

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = AppScope.of(context);
    if (identical(_controller, nextController)) {
      return;
    }
    _controller?.removeListener(_scrollToBottom);
    _controller = nextController;
    nextController.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _controller?.removeListener(_scrollToBottom);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller ?? AppScope.of(context);
    final text = controller.terminalLines.join();
    return _FramePanel(
      height: 260,
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: depotLineDim))),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 18, color: depotMuted),
                const SizedBox(width: 8),
                Text('终端',
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(color: depotText, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  onPressed: controller.toggleTerminal,
                  icon: const Icon(Icons.keyboard_arrow_down, color: depotMuted),
                  tooltip: '收起终端',
                ),
              ],
            ),
          ),
          Expanded(
            child: DepotScrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SelectableText(
                    text.isEmpty ? '暂无输出' : text,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Color(0xffd6eadf),
                      fontFamily: 'monospace',
                      fontFamilyFallback: [
                        'Noto Sans Mono CJK SC',
                        'Noto Sans CJK SC',
                        'Noto Sans CJK',
                        'WenQuanYi Micro Hei',
                      ],
                      fontSize: 13,
                      height: 1.45,
                    ),
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

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: depotText,
        side: const BorderSide(color: depotLine),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: depotAccent,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: depotAccent.withValues(alpha: 0.48), blurRadius: 18, spreadRadius: 2)],
      ),
    );
  }
}

class _FramePanel extends StatelessWidget {
  const _FramePanel({
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: depotPanel.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: depotLine.withValues(alpha: 0.76)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}
