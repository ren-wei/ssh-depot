import 'package:ssh_depot/feature/utils/shell_quote.dart';
import 'package:ssh_depot/feature/parts/nginx/utils/nginx_utils.dart';

bool isSafeCertificateName(String value) {
  return isSafeSiteName(value);
}

String certificateListCommand() {
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

String certificateDetailsCommand(String certName) {
  return 'fullchain=/etc/letsencrypt/live/${shellQuote(certName)}/fullchain.pem; '
      'if [ ! -f "\$fullchain" ]; then echo "未找到证书: \$fullchain"; exit 1; fi; '
      'openssl x509 -in "\$fullchain" -noout -subject -issuer -dates -serial -ext subjectAltName';
}

String certificateEnvironmentCommand() {
  return 'set +e; '
      'echo "[certbot]"; command -v certbot && certbot --version || echo "certbot 未安装"; '
      'echo; echo "[certbot plugins]"; certbot plugins 2>/dev/null || true; '
      'echo; echo "[nginx]"; nginx -t; '
      'echo; echo "[nginx status]"; systemctl is-active nginx 2>/dev/null || true; '
      'echo; echo "[listen 80/443]"; ss -lntp 2>/dev/null | grep -E ":(80|443)[[:space:]]" || true';
}

String requestCertificateCommand({
  required List<String> domains,
  required String email,
  required bool useWebroot,
  required String webroot,
}) {
  final domainArgs = domains.map((domain) => '-d ${shellQuote(domain)}').join(' ');
  return useWebroot
      ? 'certbot certonly --webroot -w ${shellQuote(webroot.trim())} $domainArgs '
          '--non-interactive --agree-tos -m ${shellQuote(email.trim())}'
      : 'certbot --nginx $domainArgs --non-interactive --agree-tos -m ${shellQuote(email.trim())}';
}

String renewCertificateCommand(String certName, {bool dryRun = false}) {
  return 'certbot renew --cert-name ${shellQuote(certName)}${dryRun ? ' --dry-run' : ''}';
}

String updateCertificateDomainsCommand({
  required String certName,
  required List<String> domains,
  required bool useWebroot,
  required String webroot,
}) {
  final domainArgs = domains.map((domain) => '-d ${shellQuote(domain)}').join(' ');
  return useWebroot
      ? 'certbot certonly --webroot -w ${shellQuote(webroot.trim())} --cert-name ${shellQuote(certName)} '
          '$domainArgs --non-interactive'
      : 'certbot --nginx --cert-name ${shellQuote(certName)} $domainArgs --non-interactive';
}

String deleteCertificateCommand(String certName) {
  return 'certbot delete --cert-name ${shellQuote(certName)} --non-interactive';
}
