import 'dart:io';

String resolveHomeDirectory() {
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty && !home.contains('/Library/Containers/')) {
    return home;
  }

  if (Platform.isMacOS) {
    final user = Platform.environment['USER'];
    if (user != null && user.isNotEmpty) {
      return '/Users/$user';
    }
  }

  return home ?? Directory.current.path;
}
