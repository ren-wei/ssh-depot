import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.selectedPath, required this.child, super.key});

  final String selectedPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndexForPath(selectedPath);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ssh depot'),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.link_off),
            label: const Text('未连接'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
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
      bottomNavigationBar: const _TerminalStatusBar(),
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
  _ShellItem(path: '/', label: '概览', icon: Icons.dashboard_outlined),
  _ShellItem(path: '/packages', label: '软件包', icon: Icons.inventory_2_outlined),
  _ShellItem(path: '/services', label: '服务', icon: Icons.toggle_on_outlined),
  _ShellItem(path: '/nginx', label: 'Nginx', icon: Icons.account_tree_outlined),
  _ShellItem(path: '/settings', label: '设置', icon: Icons.settings_outlined),
];

class _TerminalStatusBar extends StatelessWidget {
  const _TerminalStatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: const Row(
        children: [
          Icon(Icons.terminal, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('空闲')),
          Icon(Icons.keyboard_arrow_up),
        ],
      ),
    );
  }
}
