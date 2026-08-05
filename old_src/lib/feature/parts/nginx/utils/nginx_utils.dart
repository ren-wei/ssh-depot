import 'dart:convert';

import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/classes/nginx_template_definition.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

bool isSafeSiteName(String value) {
  return RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*$').hasMatch(value);
}

String refreshNginxSitesCommand() {
  return 'echo "__sites_available__"; '
      'find /etc/nginx/sites-available -maxdepth 1 -type f -printf "%f\\n" 2>/dev/null || true; '
      'echo "__sites_enabled__"; '
      'find /etc/nginx/sites-enabled -maxdepth 1 \\( -type f -o -type l \\) -printf "%f\\n" 2>/dev/null || true; '
      'echo "__site_domains__"; '
      'for sitefile in /etc/nginx/sites-available/*; do '
      '  [ -f "\$sitefile" ] || continue; '
      '  sitename=\$(basename "\$sitefile"); '
      '  domains=\$(sed -n "s/^[[:space:]]*server_name[[:space:]]\\+\\([^;]*\\);.*/\\1/p" "\$sitefile" '
      '    | tr "\\n" " " | tr -s " " | sed "s/^ //;s/ \$//" || true); '
      '  printf "%s|%s\\n" "\$sitename" "\$domains"; '
      'done; '
      'echo "__certificates__"; '
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

String enableNginxSiteCommand(String site) {
  return 'ln -sfn /etc/nginx/sites-available/${shellQuote(site)} /etc/nginx/sites-enabled/${shellQuote(site)} && '
      'nginx -t && systemctl reload nginx';
}

String disableNginxSiteCommand(String site) {
  return 'rm -f /etc/nginx/sites-enabled/${shellQuote(site)} && nginx -t && systemctl reload nginx';
}

String writeNginxSiteCommand({required String siteName, required String config}) {
  final encoded = base64.encode(utf8.encode(config));
  final targetFile = '/etc/nginx/sites-available/$siteName';
  return 'set -e; '
      'target=${shellQuote(targetFile)}; '
      'backup="\$target.ssh-depot.bak.\$(date +%Y%m%d%H%M%S)"; '
      'if [ -f "\$target" ]; then cp "\$target" "\$backup"; fi; '
      'printf %s ${shellQuote(encoded)} | base64 -d > "\$target"; '
      'if ! nginx -t; then '
      '  if [ -n "\${backup:-}" ] && [ -f "\$backup" ]; then cp "\$backup" "\$target"; fi; '
      '  nginx -t || true; '
      '  exit 1; '
      'fi; '
      'ln -sfn "\$target" /etc/nginx/sites-enabled/${shellQuote(siteName)}; '
      'systemctl reload nginx';
}

String readNginxSiteConfigCommand(String site) {
  return '${nginxSiteTargetPrefix(site)} cat "\$target"';
}

String testNginxSiteConfigCommand({required String siteName, required String config}) {
  final encoded = base64.encode(utf8.encode(config));
  return 'set -e; '
      '${nginxSiteTargetPrefix(siteName)} '
      'backup="\$target.ssh-depot.test.\$(date +%Y%m%d%H%M%S)"; '
      'had_original=0; '
      'if [ -f "\$target" ]; then had_original=1; cp "\$target" "\$backup"; fi; '
      'restore() { if [ "\$had_original" = "1" ]; then cp "\$backup" "\$target"; else rm -f "\$target"; fi; rm -f "\$backup"; }; '
      'printf %s ${shellQuote(encoded)} | base64 -d > "\$target"; '
      'if nginx -t; then restore; exit 0; else code=\$?; restore; exit "\$code"; fi';
}

String saveNginxSiteConfigCommand({required String siteName, required String config}) {
  final encoded = base64.encode(utf8.encode(config));
  return 'set -e; '
      '${nginxSiteTargetPrefix(siteName)} '
      'backup="\$target.ssh-depot.bak.\$(date +%Y%m%d%H%M%S)"; '
      'if [ -f "\$target" ]; then cp "\$target" "\$backup"; fi; '
      'printf %s ${shellQuote(encoded)} | base64 -d > "\$target"; '
      'if ! nginx -t; then '
      '  if [ -f "\$backup" ]; then cp "\$backup" "\$target"; else rm -f "\$target"; fi; '
      '  nginx -t || true; '
      '  exit 1; '
      'fi; '
      'systemctl reload nginx';
}

String deleteNginxSiteCommand(String site) {
  return 'rm -f /etc/nginx/sites-enabled/${shellQuote(site)} '
      '/etc/nginx/sites-available/${shellQuote(site)} && nginx -t && systemctl reload nginx';
}

String nginxSiteTargetPrefix(String site) {
  final enabledPath = '/etc/nginx/sites-enabled/$site';
  final availablePath = '/etc/nginx/sites-available/$site';
  return 'enabled=${shellQuote(enabledPath)}; '
      'available=${shellQuote(availablePath)}; '
      'if [ -e "\$enabled" ] || [ -L "\$enabled" ]; then '
      '  resolved=\$(readlink -f "\$enabled" 2>/dev/null || true); '
      '  if [ -n "\$resolved" ]; then target="\$resolved"; else target="\$enabled"; fi; '
      'else '
      '  target="\$available"; '
      'fi;';
}

NginxSitesParseResult parseNginxSites(String output) {
  final available = <String>{};
  final enabled = <String>{};
  final siteDomains = <String, List<String>>{};
  final certificates = <NginxCertificateInfo>[];
  var section = '';

  for (final rawLine in const LineSplitter().convert(output)) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    if (line == '__sites_available__' ||
        line == '__sites_enabled__' ||
        line == '__site_domains__' ||
        line == '__certificates__') {
      section = line;
      continue;
    }
    if (section == '__sites_available__') {
      if (isSafeSiteName(line)) {
        available.add(line);
      }
    } else if (section == '__sites_enabled__') {
      if (isSafeSiteName(line)) {
        enabled.add(line);
      }
    } else if (section == '__site_domains__') {
      final parts = line.split('|');
      if (parts.isNotEmpty && isSafeSiteName(parts.first)) {
        siteDomains[parts.first] = parseDomainList(parts.length > 1 ? parts[1] : '');
      }
    } else if (section == '__certificates__') {
      final certificate = parseCertificateLine(line);
      if (certificate != null) {
        certificates.add(certificate);
      }
    }
  }

  final names = {...available, ...enabled}.toList()..sort();
  final sites = [
    for (final name in names)
      NginxSite(
        name: name,
        enabled: enabled.contains(name),
        availablePath: '/etc/nginx/sites-available/$name',
        configType: inferNginxSiteType(name),
        serverNames: siteDomains[name] ?? const [],
        certificate: matchCertificate(
          siteName: name,
          serverNames: siteDomains[name] ?? const [],
          certificates: certificates,
        ),
      ),
  ];
  return NginxSitesParseResult(sites: sites, certificates: certificates);
}

NginxCertificateInfo? parseCertificateLine(String line) {
  final parts = line.split('|');
  if (parts.length < 4 || !isSafeSiteName(parts[0])) {
    return null;
  }
  final epoch = int.tryParse(parts[1]);
  final expiresAt = epoch == null || epoch <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
  final domains = parseDomainList(parts.length > 5 ? parts[5] : (parts.length > 4 ? parts[4] : ''));
  return NginxCertificateInfo(
    certName: parts[0],
    expiresAt: expiresAt,
    issuer: parts[2].isEmpty ? null : parts[2],
    fullchainPath: parts[3],
    privateKeyPath: parts.length > 5 && parts[4].isNotEmpty ? parts[4] : null,
    domains: domains,
    status: certificateStatus(expiresAt),
  );
}

List<String> parseDomainList(String value) {
  return value
      .split(RegExp(r'\s+'))
      .map((domain) => domain.trim())
      .where((domain) =>
          domain.isNotEmpty && domain != '_' && isSafeSiteName(domain.replaceFirst(RegExp(r'^\*\.'), 'wildcard.')))
      .toSet()
      .toList();
}

List<String> parseCertificateRequestDomains(String value) {
  return value
      .split(RegExp(r'[\s,]+'))
      .map((domain) => domain.trim())
      .where((domain) => domain.isNotEmpty && isSafeSiteName(domain.replaceFirst(RegExp(r'^\*\.'), 'wildcard.')))
      .toSet()
      .toList();
}

NginxCertificateInfo? matchCertificate({
  required String siteName,
  required List<String> serverNames,
  required List<NginxCertificateInfo> certificates,
}) {
  final candidates = {
    siteName,
    ...serverNames,
  };
  for (final certificate in certificates) {
    final certificateNames = {
      certificate.certName,
      ...certificate.domains,
    };
    if (candidates.any(certificateNames.contains)) {
      return certificate;
    }
  }
  return null;
}

CertificateStatus certificateStatus(DateTime? expiresAt) {
  if (expiresAt == null) {
    return CertificateStatus.unknown;
  }
  final now = DateTime.now();
  if (expiresAt.isBefore(now)) {
    return CertificateStatus.expired;
  }
  if (expiresAt.difference(now).inDays <= 30) {
    return CertificateStatus.expiringSoon;
  }
  return CertificateStatus.valid;
}

NginxSiteType inferNginxSiteType(String name) {
  if (name.contains('proxy') || name.contains('api')) {
    return NginxSiteType.reverseProxy;
  }
  return NginxSiteType.custom;
}

String staticSiteTemplate(bool enableLogs) {
  return '''
server {
    listen 80;
    server_name {{domain}};
    root {{root_path}};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
${enableLogs ? '''
    access_log /var/log/nginx/{{domain}}_access.log;
    error_log /var/log/nginx/{{domain}}_error.log;
''' : ''}
}
''';
}

const reverseProxyTemplate = '''
server {
    listen 80;
    server_name {{domain}};

    location / {
        proxy_pass http://{{upstream_host}}:{{upstream_port}};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
''';

const builtInWebsiteTemplates = [
  NginxTemplateDefinition(
    id: 'static_site',
    name: '静态网站',
    type: '静态站点',
    description: '标准 root + try_files 配置',
    builtIn: true,
    content: '''
server {
    listen 80;
    server_name {{domain}};
    root {{root_path}};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    access_log /var/log/nginx/{{domain}}_access.log;
    error_log /var/log/nginx/{{domain}}_error.log;
}
''',
  ),
  NginxTemplateDefinition(
    id: 'reverse_proxy',
    name: '反向代理',
    type: '反向代理',
    description: '转发到本机上游服务',
    builtIn: true,
    content: '''
server {
    listen 80;
    server_name {{domain}};

    location / {
        proxy_pass http://{{upstream_host}}:{{upstream_port}};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
''',
  ),
];

class NginxSitesParseResult {
  const NginxSitesParseResult({required this.sites, required this.certificates});

  final List<NginxSite> sites;
  final List<NginxCertificateInfo> certificates;
}
