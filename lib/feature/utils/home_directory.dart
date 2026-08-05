import 'dart:io';

String resolveHomeDirectory({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final home = env['HOME'];
  if (home != null && home.trim().isNotEmpty) {
    return home;
  }
  final userProfile = env['USERPROFILE'];
  if (userProfile != null && userProfile.trim().isNotEmpty) {
    return userProfile;
  }
  return Directory.current.path;
}
