import 'package:ssh_depot/feature/packages/commands/command.dart';

Command certificateListCommand() {
  return const CertificateListCommand();
}

class CertificateListCommand implements Command {
  const CertificateListCommand();

  @override
  String get summary => '刷新证书';

  @override
  String get text {
    return 'echo "__certificates__"; '
        'for certdir in /etc/letsencrypt/live/*; do '
        '  [ -d "\$certdir" ] || continue; '
        '  name=\$(basename "\$certdir"); fullchain="\$certdir/fullchain.pem"; '
        '  [ -f "\$fullchain" ] || continue; '
        '  end_date=\$(openssl x509 -in "\$fullchain" -noout -enddate 2>/dev/null | cut -d= -f2- || true); '
        '  end_epoch=\$(date -d "\$end_date" +%s 2>/dev/null || echo 0); '
        '  issuer=\$(openssl x509 -in "\$fullchain" -noout -issuer 2>/dev/null | sed "s/^issuer=//" || true); '
        '  names=\$(openssl x509 -in "\$fullchain" -noout -ext subjectAltName 2>/dev/null '
        '    | grep -o "DNS:[^, ]*" | sed "s/^DNS://" | tr "\\n" " " | tr -s " " | sed "s/^ //;s/ \$//" || true); '
        '  private_key="\$certdir/privkey.pem"; '
        '  printf "%s|%s|%s|%s|%s|%s\\n" "\$name" "\$end_epoch" "\$issuer" "\$fullchain" "\$private_key" "\$names"; '
        'done';
  }
}
