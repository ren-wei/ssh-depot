import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ssh_depot/feature/app/app_bootstrap.dart';
import 'package:ssh_depot/feature/cubits/app_connection_cubit.dart';
import 'package:ssh_depot/feature/pages/connection_page.dart';
import 'package:ssh_depot/feature/pages/nginx_page.dart';
import 'package:ssh_depot/feature/pages/overview_page.dart';
import 'package:ssh_depot/feature/pages/packages_page.dart';
import 'package:ssh_depot/feature/pages/services_page.dart';
import 'package:ssh_depot/feature/pages/settings_page.dart';
import 'package:ssh_depot/feature/pages/ssl_page.dart';
import 'package:ssh_depot/feature/session/connected_session.dart';
import 'package:ssh_depot/feature/shell/app_shell.dart';

void main() {
  runApp(const SshDepotApp());
}

const depotBg = Color(0xff101414);
const depotPanel = Color(0xcc18201f);
const depotAccent = Color(0xff49d18d);

class SshDepotApp extends StatelessWidget {
  const SshDepotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBootstrap(
      child: Builder(
        builder: (context) {
          final appConnectionCubit = context.read<AppConnectionCubit>();
          return MaterialApp.router(
            title: 'ssh depot',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: depotAccent,
                brightness: Brightness.dark,
                surface: depotPanel,
              ),
              scaffoldBackgroundColor: depotBg,
              canvasColor: depotBg,
              cardTheme: const CardThemeData(color: depotPanel, surfaceTintColor: Colors.transparent),
              dialogTheme: const DialogThemeData(backgroundColor: depotPanel, surfaceTintColor: Colors.transparent),
              useMaterial3: true,
            ),
            routerConfig: _router(appConnectionCubit),
          );
        },
      ),
    );
  }
}

GoRouter _router(AppConnectionCubit appConnectionCubit) {
  return GoRouter(
    initialLocation: '/connect',
    refreshListenable: appConnectionCubit,
    redirect: (context, state) {
      final hasTarget = appConnectionCubit.hasTarget;
      final onConnectPage = state.uri.path == '/connect';
      if (!hasTarget && !onConnectPage) {
        return '/connect';
      }
      if (hasTarget && onConnectPage) {
        return '/overview';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/connect',
        pageBuilder: (context, state) => _contentPage(state, const ConnectionPage()),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final target = appConnectionCubit.target;
          if (target == null) {
            return const ConnectionPage();
          }
          return ConnectedSession(
            key: ValueKey(target.address),
            target: target,
            child: AppShell(selectedPath: state.uri.path, child: child),
          );
        },
        routes: [
          GoRoute(path: '/overview', pageBuilder: (context, state) => _contentPage(state, const OverviewPage())),
          GoRoute(path: '/packages', pageBuilder: (context, state) => _contentPage(state, const PackagesPage())),
          GoRoute(path: '/services', pageBuilder: (context, state) => _contentPage(state, const ServicesPage())),
          GoRoute(path: '/nginx', pageBuilder: (context, state) => _contentPage(state, const NginxPage())),
          GoRoute(path: '/ssl', pageBuilder: (context, state) => _contentPage(state, const SslPage())),
          GoRoute(path: '/settings', pageBuilder: (context, state) => _contentPage(state, const SettingsPage())),
        ],
      ),
    ],
  );
}

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
