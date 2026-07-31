import 'package:flutter_test/flutter_test.dart';

import 'package:ssh_depot/main.dart';

void main() {
  testWidgets('shows the desktop app shell', (tester) async {
    await tester.pumpWidget(const SshDepotApp());
    await tester.pumpAndSettle();

    expect(find.text('ssh depot'), findsOneWidget);
    expect(find.text('概览'), findsOneWidget);
    expect(find.text('连接服务器'), findsOneWidget);
  });
}
