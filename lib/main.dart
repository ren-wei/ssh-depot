import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'feature/components/app_scope.dart';
import 'feature/cubits/app_controller.dart';
import 'feature/pages/nginx_page.dart';
import 'feature/pages/overview_page.dart';
import 'feature/pages/packages_page.dart';
import 'feature/pages/services_page.dart';
import 'feature/pages/settings_page.dart';

void main() {
  runApp(const SshDepotApp());
}

class SshDepotApp extends StatefulWidget {
  const SshDepotApp({super.key});

  @override
  State<SshDepotApp> createState() => _SshDepotAppState();
}

class _SshDepotAppState extends State<SshDepotApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: MaterialApp.router(
        title: 'ssh depot',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1f7a5f)),
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const OverviewPage()),
    GoRoute(path: '/packages', builder: (context, state) => const PackagesPage()),
    GoRoute(path: '/services', builder: (context, state) => const ServicesPage()),
    GoRoute(path: '/nginx', builder: (context, state) => const NginxPage()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
  ],
);
