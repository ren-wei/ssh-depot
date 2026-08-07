import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/commands/echo_command.dart';
import 'package:ssh_depot/feature/packages/commands/nginx_command.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

export 'package:ssh_depot/feature/packages/certificates/certificate_commands.dart';

Command certificateDetailsCommand(String certName) {
  return CertificateDetailsCommand(certName);
}

Command certificateEnvironmentCommand() {
  return const CertificateEnvironmentCommand();
}

Command requestCertificateCommand({
  required List<String> domains,
  required String email,
  required bool useWebroot,
  required String webroot,
}) {
  return RequestCertificateCommand(
    domains: domains,
    email: email,
    useWebroot: useWebroot,
    webroot: webroot,
  );
}

Command renewCertificateCommand(String certName, {bool dryRun = false}) {
  return RenewCertificateCommand(certName, dryRun: dryRun);
}

Command updateCertificateDomainsCommand({
  required String certName,
  required List<String> domains,
  required bool useWebroot,
  required String webroot,
}) {
  return UpdateCertificateDomainsCommand(
    certName: certName,
    domains: domains,
    useWebroot: useWebroot,
    webroot: webroot,
  );
}

Command deleteCertificateCommand(String certName) {
  return DeleteCertificateCommand(certName);
}

class CertificateDetailsCommand extends Command {
  const CertificateDetailsCommand(this.certName);

  final String certName;

  @override
  String get summary => '查看证书 $certName';

  @override
  String get text {
    return 'fullchain=/etc/letsencrypt/live/${shellQuote(certName)}/fullchain.pem; '
        'if [ ! -f "\$fullchain" ]; then ${EchoCommand('未找到证书: \$fullchain').text}; exit 1; fi; '
        'openssl x509 -in "\$fullchain" -noout -subject -issuer -dates -serial -ext subjectAltName';
  }

  @override
  RemoteCommandResult parse(RemoteCommandResult result) => result;
}

class CertificateEnvironmentCommand extends Command {
  const CertificateEnvironmentCommand();

  @override
  String get summary => '检查证书环境';

  @override
  String get text {
    return 'set +e; '
        '${EchoCommand('[certbot]').text}; command -v certbot && certbot --version || ${EchoCommand('certbot 未安装').text}; '
        'echo; ${EchoCommand('[certbot plugins]').text}; certbot plugins 2>/dev/null || true; '
        'echo; ${EchoCommand('[nginx]').text}; ${NginxCommand.test().text}; '
        'echo; ${EchoCommand('[nginx status]').text}; systemctl is-active nginx 2>/dev/null || true; '
        'echo; ${EchoCommand('[listen 80/443]').text}; ss -lntp 2>/dev/null | grep -E ":(80|443)[[:space:]]" || true';
  }

  @override
  RemoteCommandResult parse(RemoteCommandResult result) => result;
}

class RequestCertificateCommand extends Command {
  const RequestCertificateCommand({
    required this.domains,
    required this.email,
    required this.useWebroot,
    required this.webroot,
  });

  final List<String> domains;
  final String email;
  final bool useWebroot;
  final String webroot;

  @override
  String get summary => '申请证书 ${domains.first}';

  @override
  String get text {
    final domainArgs = domains.map((domain) => '-d ${shellQuote(domain)}').join(' ');
    return useWebroot
        ? 'certbot certonly --webroot -w ${shellQuote(webroot.trim())} $domainArgs '
            '--non-interactive --agree-tos -m ${shellQuote(email.trim())}'
        : 'certbot --nginx $domainArgs --non-interactive --agree-tos -m ${shellQuote(email.trim())}';
  }

  @override
  RemoteCommandResult parse(RemoteCommandResult result) => result;
}

class RenewCertificateCommand extends Command {
  const RenewCertificateCommand(this.certName, {this.dryRun = false});

  final String certName;
  final bool dryRun;

  @override
  String get summary => dryRun ? '测试续期证书' : '续期证书';

  @override
  String get text => 'certbot renew --cert-name ${shellQuote(certName)}${dryRun ? ' --dry-run' : ''}';

  @override
  RemoteCommandResult parse(RemoteCommandResult result) => result;
}

class UpdateCertificateDomainsCommand extends Command {
  const UpdateCertificateDomainsCommand({
    required this.certName,
    required this.domains,
    required this.useWebroot,
    required this.webroot,
  });

  final String certName;
  final List<String> domains;
  final bool useWebroot;
  final String webroot;

  @override
  String get summary => '更新证书域名 $certName';

  @override
  String get text {
    final domainArgs = domains.map((domain) => '-d ${shellQuote(domain)}').join(' ');
    return useWebroot
        ? 'certbot certonly --webroot -w ${shellQuote(webroot.trim())} --cert-name ${shellQuote(certName)} '
            '$domainArgs --non-interactive'
        : 'certbot --nginx --cert-name ${shellQuote(certName)} $domainArgs --non-interactive';
  }

  @override
  RemoteCommandResult parse(RemoteCommandResult result) => result;
}

class DeleteCertificateCommand extends Command {
  const DeleteCertificateCommand(this.certName);

  final String certName;

  @override
  String get summary => '删除证书 $certName';

  @override
  String get text => 'certbot delete --cert-name ${shellQuote(certName)} --non-interactive';

  @override
  RemoteCommandResult parse(RemoteCommandResult result) => result;
}
