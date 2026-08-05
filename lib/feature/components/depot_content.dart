import 'package:flutter/material.dart';

import 'package:ssh_depot/feature/shell/app_shell.dart';
import 'depot_scrollbar.dart';

class DepotContent extends StatelessWidget {
  const DepotContent({
    required this.title,
    required this.child,
    this.subtitle = '',
    this.actions = const [],
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return DepotContentPage(
      title: title,
      subtitle: subtitle,
      actions: actions,
      children: [child],
    );
  }
}

class DepotContentPage extends StatefulWidget {
  const DepotContentPage({
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  State<DepotContentPage> createState() => _DepotContentPageState();
}

class _DepotContentPageState extends State<DepotContentPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DepotScrollbar(
      controller: _scrollController,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
          DepotPanel(
            padding: const EdgeInsets.fromLTRB(34, 28, 34, 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: depotText,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: depotMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                if (widget.actions.isNotEmpty) ...[
                  const SizedBox(width: 20),
                  Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end, children: widget.actions),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          ...widget.children,
        ],
      ),
    );
  }
}

class DepotPanel extends StatelessWidget {
  const DepotPanel({
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.height,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return DepotCard(
      height: height,
      padding: padding,
      child: child,
    );
  }
}

class DepotSectionHeader extends StatelessWidget {
  const DepotSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: depotText,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 18),
          trailing!,
        ],
      ],
    );
  }
}

class DepotRow extends StatelessWidget {
  const DepotRow({
    required this.child,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    super.key,
  });

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      constraints: height == null ? const BoxConstraints(minHeight: 58) : null,
      padding: padding,
      decoration: BoxDecoration(
        color: depotPanelAlt.withValues(alpha: depotMutedSurfaceAlpha),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: depotLineDim.withValues(alpha: 0.78)),
      ),
      child: child,
    );
  }
}

class DepotDot extends StatelessWidget {
  const DepotDot({required this.color, this.size = 16, super.key});

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

class DepotStatusPill extends StatelessWidget {
  const DepotStatusPill({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xff06311f), fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

InputDecoration depotInputDecoration(String label, {String? hint, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 18),
    filled: true,
    fillColor: depotTerminal.withValues(alpha: 0.62),
    labelStyle: const TextStyle(color: depotMuted, fontWeight: FontWeight.w700),
    hintStyle: TextStyle(color: depotMuted.withValues(alpha: 0.68)),
    prefixIconColor: depotMuted,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: depotLineDim),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: depotAccent, width: 1.4),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: depotLineDim.withValues(alpha: 0.5)),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
  );
}

ButtonStyle depotFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: depotAccent,
    foregroundColor: const Color(0xff06311f),
    disabledBackgroundColor: depotPanelAlt.withValues(alpha: 0.42),
    disabledForegroundColor: depotMuted.withValues(alpha: 0.52),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    textStyle: const TextStyle(fontWeight: FontWeight.w900),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}

ButtonStyle depotOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: depotText,
    disabledForegroundColor: depotMuted.withValues(alpha: 0.5),
    side: const BorderSide(color: depotLine),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}

TextStyle depotMutedText(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall!.copyWith(color: depotMuted, fontWeight: FontWeight.w700);
}
