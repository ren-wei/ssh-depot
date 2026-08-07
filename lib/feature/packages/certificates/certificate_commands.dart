import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/certificates/certificate_parser.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';

Command certificateListCommand() {
  return const CertificateListCommand();
}

class CertificateListCommand extends Command {
  const CertificateListCommand();

  @override
  String get summary => '刷新证书列表';

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

  @override
  List<NginxCertificateInfo>? parse(RemoteCommandResult result) {
    if (!result.succeeded) {
      return null;
    }
    return parseCertificateList(result.output);
  }
}
