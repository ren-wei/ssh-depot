import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../parts/connection/views/connection_view.dart';
import 'app_scope.dart';

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
          appBar: AppBar(
            title: Text('ssh depot · ${target.address}'),
            actions: [
              if (controller.isRunning)
                TextButton.icon(
                  onPressed: controller.cancelRunning,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('取消'),
                ),
              TextButton.icon(
                onPressed: controller.disconnect,
                icon: const Icon(Icons.link),
                label: const Text('断开'),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) => context.go(_items[index].path),
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final item in _items)
                          NavigationRailDestination(
                            icon: Icon(item.icon),
                            label: Text(item.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: child),
                  ],
                ),
              ),
              if (controller.terminalExpanded) const _TerminalPanel(),
            ],
          ),
          bottomNavigationBar: const _TerminalStatusBar(),
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
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;
}

const _items = [
  _ShellItem(path: '/overview', label: '概览', icon: Icons.dashboard_outlined),
  _ShellItem(path: '/packages', label: '软件包', icon: Icons.inventory_2_outlined),
  _ShellItem(path: '/services', label: '服务', icon: Icons.toggle_on_outlined),
  _ShellItem(path: '/nginx', label: 'Nginx', icon: Icons.account_tree_outlined),
  _ShellItem(path: '/settings', label: '设置', icon: Icons.settings_outlined),
];

class _TerminalStatusBar extends StatelessWidget {
  const _TerminalStatusBar();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          const Icon(Icons.terminal, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.statusLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: controller.toggleTerminal,
            icon: Icon(controller.terminalExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
            tooltip: controller.terminalExpanded ? '收起终端' : '展开终端',
          ),
        ],
      ),
    );
  }
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final text = controller.terminalLines.join();
    return Container(
      height: 300,
      width: double.infinity,
      color: const Color(0xff111111),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        reverse: true,
        child: SelectableText(
          text.isEmpty ? '暂无输出' : text,
          style: const TextStyle(
            color: Color(0xffeeeeee),
            fontFamily: 'monospace',
            fontFamilyFallback: [
              'Noto Sans Mono CJK SC',
              'Noto Sans CJK SC',
              'Noto Sans CJK',
              'WenQuanYi Micro Hei',
            ],
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
