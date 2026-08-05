import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/classes/nginx_template_definition.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/packages/local_config/nginx_templates_store.dart';
import 'package:ssh_depot/feature/packages/nginx_template/built_in_templates.dart';
import 'package:ssh_depot/feature/packages/nginx_template/template_manifest.dart';
import 'package:ssh_depot/feature/packages/nginx_template/template_renderer.dart';
import 'package:ssh_depot/feature/utils/home_directory.dart';

import '../utils/nginx_utils.dart';

class NginxCubit extends ChangeNotifier {
  NginxCubit({required CommandRunnerCubit commandRunnerCubit})
      : _commandRunnerCubit = commandRunnerCubit,
        _nginxTemplatesStore = NginxTemplatesStore(
          paths: ConfigPaths(homeDirectory: resolveHomeDirectory()),
        );

  final CommandRunnerCubit _commandRunnerCubit;
  final NginxTemplatesStore _nginxTemplatesStore;

  List<NginxSite> nginxSites = const [];
  List<NginxCertificateInfo> nginxCertificates = const [];
  List<NginxTemplateDefinition> customNginxTemplates = const [];

  List<TemplateManifest> get nginxTemplates => builtInNginxTemplates;
  List<NginxTemplateDefinition> get websiteTemplates => [
        ...builtInWebsiteTemplates,
        ...customNginxTemplates,
      ];

  Future<void> load() async {
    customNginxTemplates = await _nginxTemplatesStore.load();
    notifyListeners();
  }

  Future<void> refreshNginxSites() async {
    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: '刷新网站列表',
      command: refreshNginxSitesCommand(),
      timeout: const Duration(seconds: 20),
    );
    if (result == null || !result.succeeded) {
      return;
    }
    final parsed = parseNginxSites(result.output);
    nginxSites = parsed.sites;
    nginxCertificates = parsed.certificates;
    notifyListeners();
  }

  Future<void> listNginxSites() {
    return refreshNginxSites();
  }

  Future<void> enableNginxSite(String site) async {
    if (!isSafeSiteName(site)) {
      _commandRunnerCubit.setStatus('无效站点名');
      return;
    }
    await _commandRunnerCubit.runRemote(
      summary: '启用网站 $site',
      command: enableNginxSiteCommand(site),
    );
    await refreshNginxSites();
  }

  Future<void> disableNginxSite(String site) async {
    if (!isSafeSiteName(site)) {
      _commandRunnerCubit.setStatus('无效站点名');
      return;
    }
    await _commandRunnerCubit.runRemote(
      summary: '禁用网站 $site',
      command: disableNginxSiteCommand(site),
    );
    await refreshNginxSites();
  }

  Future<void> testNginx() {
    return _commandRunnerCubit.runRemote(summary: '网站语法检查', command: 'nginx -t');
  }

  Future<void> reloadNginx() {
    return _commandRunnerCubit.runRemote(summary: 'Reload Nginx', command: 'systemctl reload nginx');
  }

  Future<void> writeNginxSite({
    required String siteName,
    required String config,
  }) {
    final cleanSite = siteName.trim();
    if (!isSafeSiteName(cleanSite)) {
      _commandRunnerCubit.setStatus('站点名只能包含字母、数字、点、下划线和短横线');
      return Future.value();
    }
    if (config.trim().isEmpty) {
      _commandRunnerCubit.setStatus('配置内容不能为空');
      return Future.value();
    }

    return _commandRunnerCubit.runRemote(
      summary: '写入网站配置 $cleanSite',
      command: writeNginxSiteCommand(siteName: cleanSite, config: config),
      timeout: const Duration(minutes: 2),
    );
  }

  Future<String?> readNginxSiteConfig(String site) async {
    if (!isSafeSiteName(site)) {
      _commandRunnerCubit.setStatus('无效站点名');
      return null;
    }
    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: '读取网站配置 $site',
      command: readNginxSiteConfigCommand(site),
      timeout: const Duration(seconds: 12),
    );
    if (result == null || !result.succeeded) {
      return null;
    }
    return result.output;
  }

  Future<RemoteCommandResult?> testNginxSiteConfig({
    required String siteName,
    required String config,
  }) async {
    final cleanSite = siteName.trim();
    if (!isSafeSiteName(cleanSite)) {
      _commandRunnerCubit.setStatus('无效站点名');
      return null;
    }
    if (config.trim().isEmpty) {
      _commandRunnerCubit.setStatus('配置内容不能为空');
      return null;
    }

    return _commandRunnerCubit.runCaptureRemote(
      summary: '检查网站配置 $cleanSite',
      command: testNginxSiteConfigCommand(siteName: cleanSite, config: config),
      timeout: const Duration(minutes: 2),
    );
  }

  Future<RemoteCommandResult?> saveNginxSiteConfig({
    required String siteName,
    required String config,
  }) async {
    final cleanSite = siteName.trim();
    if (!isSafeSiteName(cleanSite)) {
      _commandRunnerCubit.setStatus('无效站点名');
      return null;
    }
    if (config.trim().isEmpty) {
      _commandRunnerCubit.setStatus('配置内容不能为空');
      return null;
    }

    final result = await _commandRunnerCubit.runCaptureRemote(
      summary: '保存网站配置 $cleanSite',
      command: saveNginxSiteConfigCommand(siteName: cleanSite, config: config),
      timeout: const Duration(minutes: 2),
    );
    await refreshNginxSites();
    return result;
  }

  Future<void> deleteNginxSite(String site) async {
    if (!isSafeSiteName(site)) {
      _commandRunnerCubit.setStatus('无效站点名');
      return;
    }
    await _commandRunnerCubit.runRemote(
      summary: '删除网站 $site',
      command: deleteNginxSiteCommand(site),
      timeout: const Duration(minutes: 2),
    );
    await refreshNginxSites();
  }

  Future<void> createNginxSite({
    required String siteName,
    required String config,
  }) async {
    final result = await saveNginxSiteConfig(siteName: siteName, config: config);
    if (result?.succeeded == true) {
      await refreshNginxSites();
    }
  }

  Future<void> saveWebsiteTemplate({
    required String name,
    required String type,
    required String description,
    required String content,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _commandRunnerCubit.setStatus('请输入模板名称');
      return;
    }
    if (content.trim().isEmpty) {
      _commandRunnerCubit.setStatus('模板内容不能为空');
      return;
    }
    final template = NginxTemplateDefinition(
      id: 'custom_${_stableHash('$cleanName|${DateTime.now().microsecondsSinceEpoch}')}',
      name: cleanName,
      type: type.trim().isEmpty ? '自定义' : type.trim(),
      description: description.trim().isEmpty ? null : description.trim(),
      content: content,
    );
    try {
      await _nginxTemplatesStore.save(template);
      customNginxTemplates = await _nginxTemplatesStore.load();
      _commandRunnerCubit.setStatus('✓ 已保存模板 $cleanName');
      notifyListeners();
    } catch (error) {
      _commandRunnerCubit.setStatus('✗ 保存模板失败: $error');
    }
  }

  String renderNginxTemplate(String templateId, Map<String, Object?> variables) {
    final template = switch (templateId) {
      'static_site' => staticSiteTemplate(variables['enable_logs'] == true),
      'reverse_proxy' => reverseProxyTemplate,
      _ => '',
    };
    return const TemplateRenderer().render(template: template, variables: variables);
  }

  void clear() {
    nginxSites = const [];
    nginxCertificates = const [];
    notifyListeners();
  }

  String _stableHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}
