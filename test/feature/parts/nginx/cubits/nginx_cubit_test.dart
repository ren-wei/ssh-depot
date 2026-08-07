import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/parts/nginx/cubits/nginx_cubit.dart';
import 'package:ssh_depot/feature/parts/nginx/stores/nginx_templates_store.dart';

import '../../../fake_command_runner.dart';

void main() {
  test('refreshes nginx sites and certificates', () async {
    final runner = FakeCommandRunner()
      ..responses['刷新网站列表'] = const RemoteCommandResult(
        exitCode: 0,
        output: '''
__sites_available__
example.com
__sites_enabled__
example.com
__site_domains__
example.com|example.com www.example.com
__certificates__
example.com|1893456000|CN=R3|/etc/letsencrypt/live/example.com/fullchain.pem|/etc/letsencrypt/live/example.com/privkey.pem|example.com www.example.com
''',
      );
    final cubit = NginxCubit(commandRunner: runner);

    await cubit.refreshNginxSites();

    expect(cubit.nginxSites.single.name, 'example.com');
    expect(cubit.nginxSites.single.enabled, isTrue);
    expect(cubit.nginxSites.single.certificate?.certName, 'example.com');
    expect(cubit.nginxCertificates, hasLength(1));
  });

  test('rejects invalid site name before saving config', () async {
    final runner = FakeCommandRunner();
    final cubit = NginxCubit(commandRunner: runner);

    final result = await cubit.saveNginxSiteConfig(
      siteName: 'bad site',
      config: 'server {}',
    );

    expect(result, isNull);
    expect(runner.commands, isEmpty);
    expect(runner.statusLine, '无效站点名');
  });

  test('saves and reloads custom templates', () async {
    final tempDir = await Directory.systemTemp.createTemp('ssh_depot_nginx_templates_');
    addTearDown(() => tempDir.delete(recursive: true));
    final store = NginxTemplatesStore(paths: ConfigPaths(homeDirectory: tempDir.path));
    final cubit = NginxCubit(
      commandRunner: FakeCommandRunner(),
      nginxTemplatesStore: store,
    );

    await cubit.saveWebsiteTemplate(
      name: 'API',
      type: '反向代理',
      description: '',
      content: 'server_name {{domain}};',
    );

    expect(cubit.customNginxTemplates.single.name, 'API');
    expect(
      cubit.renderNginxTemplate(cubit.customNginxTemplates.single.id, {'domain': 'example.com'}),
      contains('server_name example.com;'),
    );
  });
}
