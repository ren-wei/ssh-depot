import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ssh_depot/feature/components/app_scope.dart';
import 'package:ssh_depot/feature/components/app_shell.dart';
import 'package:ssh_depot/feature/pages/nginx_page.dart';
import 'package:ssh_depot/feature/pages/overview_page.dart';
import 'package:ssh_depot/feature/pages/packages_page.dart';
import 'package:ssh_depot/feature/pages/services_page.dart';
import 'package:ssh_depot/feature/pages/settings_page.dart';
import 'package:ssh_depot/feature/pages/ssl_page.dart';

void main() {
  runApp(const SshDepotApp());
}

class SshDepotApp extends StatefulWidget {
  const SshDepotApp({super.key});

  @override
  State<SshDepotApp> createState() => _SshDepotAppState();
}

class _SshDepotAppState extends State<SshDepotApp> {
  @override
  Widget build(BuildContext context) {
    return AppScope(
      child: MaterialApp.router(
        title: 'ssh depot',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: depotAccent,
            brightness: Brightness.dark,
            surface: depotBg,
          ),
          scaffoldBackgroundColor: depotBg,
          canvasColor: depotBg,
          dialogTheme: const DialogThemeData(backgroundColor: depotPanel, surfaceTintColor: Colors.transparent),
          fontFamilyFallback: const [
            'Noto Sans CJK SC',
            'Noto Sans CJK',
            'WenQuanYi Micro Hei',
            'Microsoft YaHei',
            'PingFang SC',
            'Arial Unicode MS',
          ],
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/overview'),
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(selectedPath: state.uri.path, child: child);
      },
      routes: [
        GoRoute(
          path: '/overview',
          pageBuilder: (context, state) => _contentPage(state, const OverviewPage()),
        ),
        GoRoute(
          path: '/packages',
          pageBuilder: (context, state) => _contentPage(state, const PackagesPage()),
        ),
        GoRoute(
          path: '/services',
          pageBuilder: (context, state) => _contentPage(state, const ServicesPage()),
        ),
        GoRoute(
          path: '/nginx',
          pageBuilder: (context, state) => _contentPage(state, const NginxPage()),
        ),
        GoRoute(
          path: '/ssl',
          pageBuilder: (context, state) => _contentPage(state, const SslPage()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _contentPage(state, const SettingsPage()),
        ),
      ],
    ),
  ],
);

CustomTransitionPage<void> _contentPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0.03, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );
}
