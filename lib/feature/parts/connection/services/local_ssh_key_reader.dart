import 'dart:io';

import 'package:ssh_depot/feature/parts/connection/classes/local_public_key.dart';

Future<LocalPublicKey?> readLocalPublicKey({Map<String, String>? environment}) async {
  final home = (environment ?? Platform.environment)['HOME'];
  if (home == null || home.isEmpty) {
    return null;
  }

  final candidates = [
    '$home/.ssh/id_ed25519.pub',
    '$home/.ssh/id_rsa.pub',
    '$home/.ssh/id_ecdsa.pub',
    '$home/.ssh/id_dsa.pub',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!await file.exists()) {
      continue;
    }
    final key = (await file.readAsString()).trim();
    if (isPublicSshKey(key)) {
      return LocalPublicKey(path: path, key: key);
    }
  }
  return null;
}

bool isPublicSshKey(String value) {
  return value.startsWith('ssh-ed25519 ') ||
      value.startsWith('ssh-rsa ') ||
      value.startsWith('ecdsa-sha2-') ||
      value.startsWith('sk-ssh-ed25519@openssh.com ') ||
      value.startsWith('sk-ecdsa-sha2-nistp256@openssh.com ');
}
