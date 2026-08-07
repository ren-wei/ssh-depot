import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/parts/nginx/commands/nginx_site_commands.dart';

void main() {
  test('builds refresh command from simple commands and sections', () {
    final command = refreshNginxSitesCommand();

    expect(command.summary, '刷新网站列表');
    expect(command.text, contains("echo '__sites_available__'"));
    expect(command.text, contains("find '/etc/nginx/sites-enabled'"));
    expect(command.text, contains('echo "__certificates__"'));
  });

  test('builds enable disable and delete site commands', () {
    expect(enableNginxSiteCommand('example.com').text, contains("ln -sfn '/etc/nginx/sites-available/example.com'"));
    expect(disableNginxSiteCommand('example.com').text, contains("rm -f '/etc/nginx/sites-enabled/example.com'"));
    expect(deleteNginxSiteCommand('example.com').text, contains("'/etc/nginx/sites-available/example.com'"));
  });

  test('builds read config command resolving enabled symlink first', () {
    final command = readNginxSiteConfigCommand('example.com');

    expect(command.summary, '读取网站配置 example.com');
    expect(command.text, startsWith("enabled='/etc/nginx/sites-enabled/example.com'"));
    expect(command.text, endsWith('cat "\$target"'));
  });

  test('builds write test and save config commands with encoded content', () {
    const config = 'server { listen 80; }';
    final encoded = base64.encode(utf8.encode(config));

    expect(writeNginxSiteCommand(siteName: 'example.com', config: config).text,
        contains("printf %s '$encoded' | base64 -d"));
    expect(testNginxSiteConfigCommand(siteName: 'example.com', config: config).text, contains('restore()'));
    expect(saveNginxSiteConfigCommand(siteName: 'example.com', config: config).text, contains('systemctl reload'));
  });

  test('builds domain extraction loop and target prefix fallback', () {
    expect(const NginxSiteDomainsCommand().text, contains('server_name'));
    expect(nginxSiteTargetPrefix('example.com'), contains('readlink -f "\$enabled"'));
  });
}
