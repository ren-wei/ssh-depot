import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/parts/connection/services/local_ssh_key_reader.dart';

void main() {
  test('validates supported public ssh key prefixes', () {
    expect(isPublicSshKey('ssh-ed25519 AAAA user@host'), isTrue);
    expect(isPublicSshKey('ssh-rsa AAAA user@host'), isTrue);
    expect(isPublicSshKey('ecdsa-sha2-nistp256 AAAA user@host'), isTrue);
    expect(isPublicSshKey('not-a-key'), isFalse);
    expect(isPublicSshKey(''), isFalse);
  });

  test('reads first valid local public key from HOME', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_connection_keys_');
    addTearDown(() => tempDir.delete(recursive: true));
    final sshDir = Directory('${tempDir.path}/.ssh');
    await sshDir.create();
    await File('${sshDir.path}/id_ed25519.pub').writeAsString('invalid');
    await File('${sshDir.path}/id_rsa.pub').writeAsString('ssh-rsa AAAA user@host\n');

    final key = await readLocalPublicKey(environment: {'HOME': tempDir.path});

    expect(key?.path, '${sshDir.path}/id_rsa.pub');
    expect(key?.key, 'ssh-rsa AAAA user@host');
  });

  test('returns null when HOME is missing or no valid key exists', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_connection_keys_');
    addTearDown(() => tempDir.delete(recursive: true));

    expect(await readLocalPublicKey(environment: const {}), isNull);
    expect(await readLocalPublicKey(environment: {'HOME': tempDir.path}), isNull);
  });
}
