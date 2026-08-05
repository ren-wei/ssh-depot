import 'package:flutter/material.dart';
import 'package:ssh_depot/feature/parts/connection/views/connection_view.dart';

class ConnectionPage extends StatelessWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: ConnectionView());
  }
}
