import 'package:ssh_depot/feature/utils/shell_quote.dart';

String authorizationCommandFor(String publicKey) {
  final quotedKey = shellQuote(publicKey);
  return 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && '
      'touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && '
      'grep -qxF $quotedKey ~/.ssh/authorized_keys || '
      'printf "%s\\n" $quotedKey >> ~/.ssh/authorized_keys';
}
