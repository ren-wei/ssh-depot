import 'package:flutter_test/flutter_test.dart';

import 'package:ssh_depot/main.dart';

void main() {
  testWidgets('shows the desktop app shell', (tester) async {
    await tester.pumpWidget(const SshDepotApp());
    await tester.pumpAndSettle();

    expect(find.text('登录服务器'), findsOneWidget);
    expect(find.text('通过 SSH 连接 root 用户后进入操作面板'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('软件包'), findsNothing);
  });
}
