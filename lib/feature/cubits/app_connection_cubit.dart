import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/packages/ssh/ssh_target.dart';

class AppConnectionCubit extends ChangeNotifier {
  SshTarget? target;
  String statusLine = '空闲';

  bool get hasTarget => target != null;

  void requestConnect(String host, {String user = 'root'}) {
    final cleanHost = host.trim();
    final cleanUser = user.trim().isEmpty ? 'root' : user.trim();
    if (cleanHost.isEmpty) {
      statusLine = '请输入 Host';
      notifyListeners();
      return;
    }
    target = SshTarget(
      host: cleanHost,
      user: cleanUser,
      controlPath: _controlPathFor(cleanHost, cleanUser),
    );
    statusLine = '正在连接 $cleanUser@$cleanHost';
    notifyListeners();
  }

  void markConnected() {
    final current = target;
    if (current == null) {
      return;
    }
    statusLine = '✓ ${current.address} 已连接';
    notifyListeners();
  }

  void failConnection(String message) {
    target = null;
    statusLine = message;
    notifyListeners();
  }

  void disconnect() {
    target = null;
    statusLine = '已断开';
    notifyListeners();
  }

  void setStatus(String value) {
    statusLine = value;
    notifyListeners();
  }

  String _controlPathFor(String host, String user) {
    final identity = '$user@$host';
    return '/tmp/ssh-depot-${_stableHash(identity)}.sock';
  }

  String _stableHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}
