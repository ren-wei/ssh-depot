import 'package:flutter/foundation.dart';
import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/classes/nginx_template_definition.dart';
import 'package:ssh_depot/feature/classes/remote_command_result.dart';
import 'package:ssh_depot/feature/packages/command_runner/command_runner.dart';
import 'package:ssh_depot/feature/packages/commands/nginx_command.dart';
import 'package:ssh_depot/feature/packages/commands/systemctl_command.dart';
import 'package:ssh_depot/feature/packages/local_config/config_paths.dart';
import 'package:ssh_depot/feature/parts/nginx/commands/nginx_site_commands.dart';
import 'package:ssh_depot/feature/parts/nginx/stores/nginx_templates_store.dart';
import 'package:ssh_depot/feature/parts/nginx/templates/built_in_templates.dart';
import 'package:ssh_depot/feature/parts/nginx/templates/nginx_site_templates.dart';
import 'package:ssh_depot/feature/parts/nginx/templates/template_manifest.dart';
import 'package:ssh_depot/feature/parts/nginx/templates/template_renderer.dart';
import 'package:ssh_depot/feature/parts/nginx/validators/nginx_site_validator.dart';
import 'package:ssh_depot/feature/utils/home_directory.dart';

class NginxCubit extends ChangeNotifier {
  NginxCubit({
    required CommandRunner commandRunner,
    NginxTemplatesStore? nginxTemplatesStore,
  })  : _commandRunner = commandRunner,
        _nginxTemplatesStore = nginxTemplatesStore ??
            NginxTemplatesStore(
              paths: ConfigPaths(homeDirectory: resolveHomeDirectory()),
            );

  final CommandRunner _commandRunner;
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
    final parsed = await _commandRunner.runCaptureCommand(
      command: refreshNginxSitesCommand(),
      timeout: const Duration(seconds: 20),
    );
    if (parsed == null) {
      return;
    }
    nginxSites = parsed.sites;
    nginxCertificates = parsed.certificates;
    notifyListeners();
  }

  Future<void> listNginxSites() {
    return refreshNginxSites();
  }

  Future<void> enableNginxSite(String site) async {
    if (!isSafeSiteName(site)) {
      _commandRunner.setStatus('无效站点名');
      return;
    }
    await _commandRunner.runCommand(
      command: enableNginxSiteCommand(site),
    );
    await refreshNginxSites();
  }

  Future<void> disableNginxSite(String site) async {
    if (!isSafeSiteName(site)) {
      _commandRunner.setStatus('无效站点名');
      return;
    }
    await _commandRunner.runCommand(
      command: disableNginxSiteCommand(site),
    );
    await refreshNginxSites();
  }

  Future<void> testNginx() {
    return _commandRunner.runCommand(command: NginxCommand.test());
  }

  Future<void> reloadNginx() {
    return _commandRunner.runCommand(command: SystemctlCommand.reload('nginx'));
  }

  Future<void> writeNginxSite({
    required String siteName,
    required String config,
  }) {
    final cleanSite = siteName.trim();
    if (!isSafeSiteName(cleanSite)) {
      _commandRunner.setStatus('站点名只能包含字母、数字、点、下划线和短横线');
      return Future.value();
    }
    if (config.trim().isEmpty) {
      _commandRunner.setStatus('配置内容不能为空');
      return Future.value();
    }

    return _commandRunner.runCommand(
      command: writeNginxSiteCommand(siteName: cleanSite, config: config),
      timeout: const Duration(minutes: 2),
    );
  }

  Future<String?> readNginxSiteConfig(String site) async {
    if (!isSafeSiteName(site)) {
      _commandRunner.setStatus('无效站点名');
      return null;
    }
    final config = await _commandRunner.runCaptureCommand(
      command: readNginxSiteConfigCommand(site),
      timeout: const Duration(seconds: 12),
    );
    return config;
  }

  Future<RemoteCommandResult?> testNginxSiteConfig({
    required String siteName,
    required String config,
  }) {
    final cleanSite = siteName.trim();
    if (!isSafeSiteName(cleanSite)) {
      _commandRunner.setStatus('无效站点名');
      return Future.value();
    }
    if (config.trim().isEmpty) {
      _commandRunner.setStatus('配置内容不能为空');
      return Future.value();
    }

    return _commandRunner.runCaptureCommand(
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
      _commandRunner.setStatus('无效站点名');
      return null;
    }
    if (config.trim().isEmpty) {
      _commandRunner.setStatus('配置内容不能为空');
      return null;
    }

    final result = await _commandRunner.runCaptureCommand(
      command: saveNginxSiteConfigCommand(siteName: cleanSite, config: config),
      timeout: const Duration(minutes: 2),
    );
    await refreshNginxSites();
    return result;
  }

  Future<void> deleteNginxSite(String site) async {
    if (!isSafeSiteName(site)) {
      _commandRunner.setStatus('无效站点名');
      return;
    }
    await _commandRunner.runCommand(
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
      _commandRunner.setStatus('请输入模板名称');
      return;
    }
    if (content.trim().isEmpty) {
      _commandRunner.setStatus('模板内容不能为空');
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
      _commandRunner.setStatus('✓ 已保存模板 $cleanName');
      notifyListeners();
    } catch (error) {
      _commandRunner.setStatus('✗ 保存模板失败: $error');
    }
  }

  String renderNginxTemplate(String templateId, Map<String, Object?> variables) {
    final template = switch (templateId) {
      'static_site' => staticSiteTemplate(variables['enable_logs'] == true),
      'reverse_proxy' => reverseProxyTemplate,
      _ => _customTemplateContent(templateId),
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

  String _customTemplateContent(String templateId) {
    for (final template in websiteTemplates) {
      if (template.id == templateId) {
        return template.content;
      }
    }
    return '';
  }
}
