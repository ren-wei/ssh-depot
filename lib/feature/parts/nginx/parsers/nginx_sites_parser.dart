import 'dart:convert';

import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/packages/certificates/certificate_parser.dart';
import 'package:ssh_depot/feature/packages/certificates/certificate_utils.dart';
import 'package:ssh_depot/feature/parts/nginx/validators/nginx_site_validator.dart';

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

NginxSiteType inferNginxSiteType(String name) {
  if (name.contains('proxy') || name.contains('api')) {
    return NginxSiteType.reverseProxy;
  }
  return NginxSiteType.custom;
}

class NginxSitesParseResult {
  const NginxSitesParseResult({
    required this.sites,
    required this.certificates,
  });

  final List<NginxSite> sites;
  final List<NginxCertificateInfo> certificates;
}
