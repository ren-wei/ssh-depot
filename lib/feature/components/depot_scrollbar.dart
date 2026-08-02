import 'package:flutter/material.dart';

const _scrollbarThumb = Color(0xff3fe09a);
const _scrollbarTrack = Color(0xff16432f);

class DepotScrollbar extends StatelessWidget {
  const DepotScrollbar({
    required this.child,
    this.controller,
    super.key,
  });

  final Widget child;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return DepotScrollbarTheme(
      child: Scrollbar(
        controller: controller,
        thumbVisibility: false,
        trackVisibility: false,
        radius: const Radius.circular(999),
        thickness: 6,
        interactive: true,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: child,
        ),
      ),
    );
  }
}

class DepotScrollbarTheme extends StatelessWidget {
  const DepotScrollbarTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(_scrollbarThumb.withValues(alpha: 0.52)),
        trackColor: WidgetStatePropertyAll(_scrollbarTrack.withValues(alpha: 0.32)),
        radius: const Radius.circular(999),
        thickness: const WidgetStatePropertyAll(6),
        thumbVisibility: const WidgetStatePropertyAll(false),
        trackVisibility: const WidgetStatePropertyAll(false),
      ),
      child: child,
    );
  }
}
