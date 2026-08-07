import 'dart:convert';

import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/certificates/certificate_commands.dart';
import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/packages/commands/echo_command.dart';
import 'package:ssh_depot/feature/packages/commands/find_command.dart';
import 'package:ssh_depot/feature/packages/commands/ln_command.dart';
import 'package:ssh_depot/feature/packages/commands/nginx_command.dart';
import 'package:ssh_depot/feature/packages/commands/rm_command.dart';
import 'package:ssh_depot/feature/packages/commands/systemctl_command.dart';
import 'package:ssh_depot/feature/parts/nginx/parsers/nginx_sites_parser.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

Command refreshNginxSitesCommand() {
  return CommandSequence(
    summary: '刷新网站列表',
    operator: ';',
    commands: [
      const EchoCommand('__sites_available__'),
      FindCommand.files('/etc/nginx/sites-available'),
      const EchoCommand('__sites_enabled__'),
      FindCommand.filesOrLinks('/etc/nginx/sites-enabled'),
      const EchoCommand('__site_domains__'),
      const NginxSiteDomainsCommand(),
      certificateListCommand(),
    ],
    parser: (result) {
      if (!result.succeeded) {
        return null;
      }
      return parseNginxSites(result.output);
    },
  );
}

Command enableNginxSiteCommand(String site) {
  return CommandSequence(
    summary: '启用网站 $site',
    commands: [
      LnCommand.symbolic(
        source: '/etc/nginx/sites-available/$site',
        target: '/etc/nginx/sites-enabled/$site',
      ),
      NginxCommand.test(),
      SystemctlCommand.reload('nginx'),
    ],
  );
}

Command disableNginxSiteCommand(String site) {
  return CommandSequence(
    summary: '禁用网站 $site',
    commands: [
      RmCommand.files(['/etc/nginx/sites-enabled/$site']),
      NginxCommand.test(),
      SystemctlCommand.reload('nginx'),
    ],
  );
}

Command writeNginxSiteCommand({required String siteName, required String config}) {
  final encoded = base64.encode(utf8.encode(config));
  final targetFile = '/etc/nginx/sites-available/$siteName';
  return WriteNginxSiteCommand(
    siteName: siteName,
    targetFile: targetFile,
    encodedConfig: encoded,
    summary: '写入网站配置 $siteName',
  );
}

Command readNginxSiteConfigCommand(String site) {
  return ReadNginxSiteConfigCommand(site);
}

Command testNginxSiteConfigCommand({required String siteName, required String config}) {
  final encoded = base64.encode(utf8.encode(config));
  return TestNginxSiteConfigCommand(siteName: siteName, encodedConfig: encoded);
}

Command saveNginxSiteConfigCommand({required String siteName, required String config}) {
  final encoded = base64.encode(utf8.encode(config));
  return SaveNginxSiteConfigCommand(siteName: siteName, encodedConfig: encoded);
}

Command deleteNginxSiteCommand(String site) {
  return CommandSequence(
    summary: '删除网站 $site',
    commands: [
      RmCommand.files(['/etc/nginx/sites-enabled/$site', '/etc/nginx/sites-available/$site']),
      NginxCommand.test(),
      SystemctlCommand.reload('nginx'),
    ],
  );
}

class NginxSiteDomainsCommand extends Command {
  const NginxSiteDomainsCommand();

  @override
  String get summary => '读取网站域名';

  @override
  String get text {
    return 'for sitefile in /etc/nginx/sites-available/*; do '
        '  [ -f "\$sitefile" ] || continue; '
        '  sitename=\$(basename "\$sitefile"); '
        '  domains=\$(sed -n "s/^[[:space:]]*server_name[[:space:]]\\+\\([^;]*\\);.*/\\1/p" "\$sitefile" '
        '    | tr "\\n" " " | tr -s " " | sed "s/^ //;s/ \$//" || true); '
        '  printf "%s|%s\\n" "\$sitename" "\$domains"; '
        'done';
  }
}

class WriteNginxSiteCommand extends Command {
  const WriteNginxSiteCommand({
    required this.siteName,
    required this.targetFile,
    required this.encodedConfig,
    required this.summary,
  });

  final String siteName;
  final String targetFile;
  final String encodedConfig;

  @override
  final String summary;

  @override
  String get text {
    return 'set -e; '
        'target=${shellQuote(targetFile)}; '
        'backup="\$target.ssh-depot.bak.\$(date +%Y%m%d%H%M%S)"; '
        'if [ -f "\$target" ]; then cp "\$target" "\$backup"; fi; '
        'printf %s ${shellQuote(encodedConfig)} | base64 -d > "\$target"; '
        'if ! ${NginxCommand.test().text}; then '
        '  if [ -n "\${backup:-}" ] && [ -f "\$backup" ]; then cp "\$backup" "\$target"; fi; '
        '  ${NginxCommand.test().text} || true; '
        '  exit 1; '
        'fi; '
        '${LnCommand.symbolicRaw(source: '\$target', target: '/etc/nginx/sites-enabled/$siteName').text}; '
        '${SystemctlCommand.reload('nginx').text}';
  }
}

class ReadNginxSiteConfigCommand extends Command {
  const ReadNginxSiteConfigCommand(this.site);

  final String site;

  @override
  String get summary => '读取网站配置 $site';

  @override
  String get text => '${nginxSiteTargetPrefix(site)} cat "\$target"';

  @override
  String? parse(RemoteCommandResult result) {
    if (!result.succeeded) {
      return null;
    }
    return result.output;
  }
}

class TestNginxSiteConfigCommand extends Command {
  const TestNginxSiteConfigCommand({
    required this.siteName,
    required this.encodedConfig,
  });

  final String siteName;
  final String encodedConfig;

  @override
  String get summary => '检查网站配置 $siteName';

  @override
  String get text {
    return 'set -e; '
        '${nginxSiteTargetPrefix(siteName)} '
        'backup="\$target.ssh-depot.test.\$(date +%Y%m%d%H%M%S)"; '
        'had_original=0; '
        'if [ -f "\$target" ]; then had_original=1; cp "\$target" "\$backup"; fi; '
        'restore() { if [ "\$had_original" = "1" ]; then cp "\$backup" "\$target"; else rm -f "\$target"; fi; rm -f "\$backup"; }; '
        'printf %s ${shellQuote(encodedConfig)} | base64 -d > "\$target"; '
        'if ${NginxCommand.test().text}; then restore; exit 0; else code=\$?; restore; exit "\$code"; fi';
  }

  @override
  RemoteCommandResult parse(RemoteCommandResult result) => result;
}

class SaveNginxSiteConfigCommand extends Command {
  const SaveNginxSiteConfigCommand({
    required this.siteName,
    required this.encodedConfig,
  });

  final String siteName;
  final String encodedConfig;

  @override
  String get summary => '保存网站配置 $siteName';

  @override
  String get text {
    return 'set -e; '
        '${nginxSiteTargetPrefix(siteName)} '
        'backup="\$target.ssh-depot.bak.\$(date +%Y%m%d%H%M%S)"; '
        'if [ -f "\$target" ]; then cp "\$target" "\$backup"; fi; '
        'printf %s ${shellQuote(encodedConfig)} | base64 -d > "\$target"; '
        'if ! ${NginxCommand.test().text}; then '
        '  if [ -f "\$backup" ]; then cp "\$backup" "\$target"; else rm -f "\$target"; fi; '
        '  ${NginxCommand.test().text} || true; '
        '  exit 1; '
        'fi; '
        '${SystemctlCommand.reload('nginx').text}';
  }

  @override
  RemoteCommandResult parse(RemoteCommandResult result) => result;
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
