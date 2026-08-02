import 'package:flutter_test/flutter_test.dart';

import 'package:ssh_depot/main.dart';

void main() {
  testWidgets('shows the desktop app shell', (tester) async {
    await tester.pumpWidget(const SshDepotApp());
    await tester.pumpAndSettle();

    expect(find.text('连接服务器'), findsOneWidget);
    expect(find.text('先从已保存的服务器里选择，或新建配置后连接。'), findsOneWidget);
    expect(find.text('开始连接'), findsOneWidget);
    expect(find.text('软件包'), findsNothing);
  });
}
