import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ssh_depot/feature/components/depot_scrollbar.dart';
import 'package:provider/provider.dart';
import 'package:ssh_depot/feature/cubits/app_connection_cubit.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/cubits/servers_cubit.dart';
import 'package:ssh_depot/feature/cubits/terminal_cubit.dart';
import 'package:ssh_depot/feature/pages/connection_page.dart';
import 'package:xterm/xterm.dart';

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
const depotCardAlpha = 0.48;
const depotCardBorderAlpha = 0.52;
const depotCardShadowAlpha = 0.12;
const depotMutedSurfaceAlpha = 0.1;
const depotMutedSurfaceStrongAlpha = 0.16;

class AppShell extends StatelessWidget {
  const AppShell({required this.selectedPath, required this.child, super.key});

  final String selectedPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndexForPath(selectedPath);
    final connection = context.read<AppConnectionCubit>();
    final runner = context.read<CommandRunnerCubit>();
    final terminal = context.read<TerminalCubit>();
    final servers = context.read<ServersCubit>();

    return AnimatedBuilder(
      animation: Listenable.merge([connection, runner, terminal, servers]),
      builder: (context, _) {
        final target = connection.target;
        if (target == null) {
          return const ConnectionPage();
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
                            title: servers.titleFor(target),
                            target: target.address,
                            isRunning: runner.isRunning,
                            onCancel: runner.cancelRunning,
                            onDisconnect: connection.disconnect,
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Sidebar(
                                  selectedIndex: selectedIndex,
                                  statusLine: runner.statusLine,
                                  onSelect: (index) {
                                    final item = _items[index];
                                    if (item.path == null) {
                                      return;
                                    }
                                    context.go(item.path!);
                                  },
                                ),
                                const SizedBox(width: 22),
                                Expanded(child: child),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _TerminalStatusBar(),
                        ],
                      ),
                      if (terminal.terminalExpanded)
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
  _ShellItem(path: '/ssl', label: 'SSL', subtitle: '证书管理', icon: Icons.key_outlined),
  _ShellItem(label: '文件', subtitle: '目录与编辑', icon: Icons.folder_outlined),
  _ShellItem(label: '日志', subtitle: '常见日志源', icon: Icons.notes_outlined),
  _ShellItem(label: 'Cron', subtitle: '定时任务', icon: Icons.schedule_outlined),
  _ShellItem(path: '/settings', label: '设置', subtitle: '服务器与偏好', icon: Icons.settings_outlined),
];

class _GlowBackdrop extends StatelessWidget {
  const _GlowBackdrop();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sx = constraints.maxWidth / 1440;
        final sy = constraints.maxHeight / 1024;
        final blurScale = (sx + sy) / 2;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            const ColoredBox(color: Color(0xff06140f)),
            _SketchGlow(
              left: -160 * sx,
              top: -120 * sy,
              width: 560 * sx,
              height: 420 * sy,
              blur: 120 * blurScale,
              color: const Color(0xff2fe38d).withValues(alpha: 0.72),
            ),
            _SketchGlow(
              left: 820 * sx,
              top: -90 * sy,
              width: 620 * sx,
              height: 420 * sy,
              blur: 120 * blurScale,
              color: const Color(0xff4bbdff).withValues(alpha: 0.68),
            ),
            _SketchGlow(
              left: 360 * sx,
              top: 690 * sy,
              width: 780 * sx,
              height: 360 * sy,
              blur: 130 * blurScale,
              color: const Color(0xff49e39b).withValues(alpha: 0.3),
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: 160 * sy,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66143224), Color(0x00143224)],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SketchGlow extends StatelessWidget {
  const _SketchGlow({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.blur,
    required this.color,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double blur;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: color,
            shape: const OvalBorder(),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.target,
    required this.isRunning,
    required this.onCancel,
    required this.onDisconnect,
  });

  final String title;
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
              Text(title,
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
              color: depotPanelAlt.withValues(alpha: depotMutedSurfaceStrongAlpha),
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
    final runner = context.read<CommandRunnerCubit>();
    final terminal = context.read<TerminalCubit>();
    return ListenableBuilder(
      listenable: Listenable.merge([runner, terminal]),
      builder: (context, _) {
        final failed = runner.statusLine.startsWith('✗');
        final succeeded = runner.statusLine.startsWith('✓');
        final statusText = _statusSummaryText(runner.statusLine);
        return _FramePanel(
          height: 58,
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: depotTerminal,
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
                onPressed: terminal.toggleTerminal,
                icon: AnimatedRotation(
                  turns: terminal.terminalExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: const Icon(Icons.keyboard_arrow_up, color: depotText),
                ),
                tooltip: terminal.terminalExpanded ? '收起终端' : '展开终端',
              ),
            ],
          ),
        );
      },
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
  final _terminal = Terminal(maxLines: 10000);
  final _terminalController = TerminalController();
  final _terminalViewKey = GlobalKey<TerminalViewState>();
  TerminalCubit? _terminalCubit;
  int _writtenLength = 0;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextTerminalCubit = context.read<TerminalCubit>();
    if (identical(_terminalCubit, nextTerminalCubit)) {
      return;
    }
    _terminalCubit?.removeListener(_scrollToBottom);
    _terminalCubit = nextTerminalCubit;
    nextTerminalCubit.addListener(_scrollToBottom);
    _scheduleTerminalSync();
  }

  @override
  void dispose() {
    _terminalCubit?.removeListener(_scrollToBottom);
    _terminalController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    _scheduleTerminalSync();
  }

  void _scheduleTerminalSync() {
    if (_syncScheduled) {
      return;
    }
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) {
        return;
      }
      final terminalCubit = _terminalCubit;
      if (terminalCubit == null) {
        return;
      }
      if (terminalCubit.terminalRawText.isNotEmpty && _terminalViewKey.currentState == null) {
        _scheduleTerminalSync();
        return;
      }
      _syncTerminal(terminalCubit.terminalRawText);
    });
  }

  void _syncTerminal(String rawText) {
    if (rawText.length < _writtenLength) {
      _terminal.eraseDisplay();
      _terminal.setCursor(0, 0);
      _writtenLength = 0;
    }
    if (rawText.length == _writtenLength) {
      return;
    }
    _terminal.write(rawText.substring(_writtenLength));
    _writtenLength = rawText.length;
  }

  @override
  Widget build(BuildContext context) {
    final terminalCubit = _terminalCubit ?? context.read<TerminalCubit>();
    return _FramePanel(
      height: 260,
      borderRadius: 20,
      padding: EdgeInsets.zero,
      backgroundColor: depotTerminal,
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
                  onPressed: terminalCubit.toggleTerminal,
                  icon: const Icon(Icons.keyboard_arrow_down, color: depotMuted),
                  tooltip: '收起终端',
                ),
              ],
            ),
          ),
          Expanded(
            child: terminalCubit.terminalRawText.isEmpty
                ? const Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: Text(
                        '暂无输出',
                        style: TextStyle(
                          color: depotMuted,
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  )
                : TerminalView(
                    key: _terminalViewKey,
                    _terminal,
                    controller: _terminalController,
                    theme: _depotTerminalTheme,
                    textStyle: const TerminalStyle(
                      fontSize: 13,
                      height: 1.25,
                      fontFamily: 'Menlo',
                      fontFamilyFallback: [
                        'Monaco',
                        'SF Mono',
                        'Consolas',
                        'Liberation Mono',
                        'Courier New',
                        'Noto Sans CJK SC',
                        'Noto Sans CJK',
                        'WenQuanYi Micro Hei',
                        'monospace',
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    readOnly: true,
                    autofocus: false,
                  ),
          ),
        ],
      ),
    );
  }
}

const _depotTerminalTheme = TerminalTheme(
  cursor: depotAccent,
  selection: Color(0x663fe09a),
  foreground: Color(0xffd6eadf),
  background: depotTerminal,
  black: Color(0xff06170f),
  red: depotRed,
  green: depotAccent,
  yellow: depotYellow,
  blue: depotBlue,
  magenta: Color(0xffd88cff),
  cyan: Color(0xff77e6d4),
  white: depotText,
  brightBlack: depotMuted,
  brightRed: Color(0xffff8cab),
  brightGreen: Color(0xff7df5bd),
  brightYellow: Color(0xffffdd85),
  brightBlue: Color(0xff8ed8ff),
  brightMagenta: Color(0xffe8b2ff),
  brightCyan: Color(0xffa8fff0),
  brightWhite: Colors.white,
  searchHitBackground: Color(0x6655bde8),
  searchHitBackgroundCurrent: Color(0x993fe09a),
  searchHitForeground: depotText,
);

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
    this.backgroundColor,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DepotCard(
      width: width,
      height: height,
      padding: padding,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      child: child,
    );
  }
}

class DepotCard extends StatelessWidget {
  const DepotCard({
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(22),
    this.borderRadius = 26,
    this.shadowBlurRadius = 28,
    this.shadowOffset = const Offset(0, 16),
    this.backgroundColor,
    super.key,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? depotPanel.withValues(alpha: depotCardAlpha),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: depotLine.withValues(alpha: depotCardBorderAlpha)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: depotCardShadowAlpha),
            blurRadius: shadowBlurRadius,
            offset: shadowOffset,
          ),
        ],
      ),
      child: child,
    );
  }
}
