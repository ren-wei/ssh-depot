import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssh_depot/feature/classes/nginx_site.dart';
import 'package:ssh_depot/feature/classes/nginx_template_definition.dart';
import 'package:ssh_depot/feature/components/depot_content.dart';
import 'package:ssh_depot/feature/components/depot_scrollbar.dart';
import 'package:ssh_depot/feature/cubits/command_runner_cubit.dart';
import 'package:ssh_depot/feature/parts/nginx/cubits/nginx_cubit.dart';
import 'package:ssh_depot/feature/shell/app_shell.dart';

class NginxView extends StatefulWidget {
  const NginxView({super.key});

  @override
  State<NginxView> createState() => _NginxViewState();
}

class _NginxViewState extends State<NginxView> {
  bool _requestedInitialRefresh = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nginx = context.read<NginxCubit>();
    if (!_requestedInitialRefresh && nginx.nginxSites.isEmpty) {
      _requestedInitialRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          nginx.refreshNginxSites();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final runner = context.read<CommandRunnerCubit>();
    final controller = context.read<NginxCubit>();
    return ListenableBuilder(
      listenable: Listenable.merge([runner, controller]),
      builder: (context, _) {
        final disabled = runner.isRunning;
        final sites = controller.nginxSites;

        return DepotContentPage(
          title: '网站管理',
          subtitle: '管理 Nginx 网站配置、启用状态和语法检查。',
          children: [
            DepotPanel(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DepotSectionHeader(
                    title: '网站列表',
                    subtitle: sites.isEmpty ? '暂无网站，点击刷新读取远端 sites-available。' : '共 ${sites.length} 个网站。',
                    trailing: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: disabled ? null : () => _openCreateSiteDialog(controller),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('新增'),
                          style: depotFilledButtonStyle(),
                        ),
                        FilledButton.icon(
                          onPressed: disabled ? null : controller.refreshNginxSites,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('刷新'),
                          style: depotFilledButtonStyle(),
                        ),
                        OutlinedButton.icon(
                          onPressed: disabled ? null : controller.testNginx,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('语法检查'),
                          style: depotOutlinedButtonStyle(),
                        ),
                        OutlinedButton.icon(
                          onPressed: disabled ? null : controller.reloadNginx,
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Reload'),
                          style: depotOutlinedButtonStyle(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  DepotRow(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: Text('网站', style: depotMutedText(context))),
                        Expanded(flex: 2, child: Text('状态', style: depotMutedText(context))),
                        Expanded(flex: 2, child: Text('证书', style: depotMutedText(context))),
                        Expanded(
                            flex: 5, child: Text('操作', textAlign: TextAlign.right, style: depotMutedText(context))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (sites.isEmpty)
                    DepotRow(
                      child: Text(
                        '点击刷新读取网站列表',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted),
                      ),
                    )
                  else
                    for (final site in sites) ...[
                      _SiteRow(
                        site: site,
                        disabled: disabled,
                        onConfig: () => _openConfigDialog(controller, site),
                        onEnable: () => controller.enableNginxSite(site.name),
                        onDisable: () => controller.disableNginxSite(site.name),
                        onDelete: () => _confirmDeleteSite(controller, site),
                      ),
                      if (site != sites.last) const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openConfigDialog(NginxCubit controller, NginxSite site) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SiteConfigDialog(controller: controller, site: site),
    );
  }

  Future<void> _openCreateSiteDialog(NginxCubit controller) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CreateSiteDialog(controller: controller),
    );
  }

  Future<void> _confirmDeleteSite(NginxCubit controller, NginxSite site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: depotPanel,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: depotLine),
          ),
          title: Text(
            '删除网站',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: depotText, fontWeight: FontWeight.w900),
          ),
          content: Text(
            '确认删除 ${site.name} 的 available 配置和 enabled 链接？',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted, fontWeight: FontWeight.w700),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: depotOutlinedButtonStyle(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: depotFilledButtonStyle(),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await controller.deleteNginxSite(site.name);
    }
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({
    required this.site,
    required this.disabled,
    required this.onConfig,
    required this.onEnable,
    required this.onDisable,
    required this.onDelete,
  });

  final NginxSite site;
  final bool disabled;
  final VoidCallback onConfig;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = site.enabled ? depotAccent : depotYellow;
    final certificate = site.certificate;
    final certificateStatus = certificate?.status ?? CertificateStatus.missing;
    final certificateColor = switch (certificateStatus) {
      CertificateStatus.valid => depotAccent,
      CertificateStatus.expiringSoon => depotYellow,
      CertificateStatus.expired => depotRed,
      CertificateStatus.missing => depotMuted,
      CertificateStatus.unknown => depotYellow,
    };
    return DepotRow(
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                DepotDot(color: statusColor, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    site.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: depotText,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _InlineStatus(label: site.statusLabel, color: statusColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _InlineStatus(label: certificate?.statusLabel ?? '未配置', color: certificateColor),
            ),
          ),
          Expanded(
            flex: 5,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _MiniAction(label: '配置', icon: Icons.code, disabled: disabled, onPressed: onConfig),
                if (site.enabled)
                  _MiniAction(label: '禁用', icon: Icons.link_off, disabled: disabled, onPressed: onDisable)
                else ...[
                  _MiniAction(label: '启用', icon: Icons.link, disabled: disabled, onPressed: onEnable),
                  _MiniAction(label: '删除', icon: Icons.delete_outline, disabled: disabled, onPressed: onDelete),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DepotDot(color: color, size: 10),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: depotText,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _CreateSiteDialog extends StatefulWidget {
  const _CreateSiteDialog({required this.controller});

  final NginxCubit controller;

  @override
  State<_CreateSiteDialog> createState() => _CreateSiteDialogState();
}

class _CreateSiteDialogState extends State<_CreateSiteDialog> {
  final _siteController = TextEditingController();
  final _configController = TextEditingController();
  final _configScrollController = ScrollController();
  String? _selectedTemplateId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _configController.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    _configController.removeListener(_onConfigChanged);
    _siteController.dispose();
    _configController.dispose();
    _configScrollController.dispose();
    super.dispose();
  }

  void _onConfigChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final templates = widget.controller.websiteTemplates;
    final hasPlaceholders = _extractPlaceholders(_configController.text).isNotEmpty;
    return AlertDialog(
      backgroundColor: depotPanel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: depotLine),
      ),
      title: Text(
        '新增网站',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: depotText, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 920,
        height: 600,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('模板', style: depotMutedText(context)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: templates.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        final selected = template.id == _selectedTemplateId;
                        return Material(
                          color: selected ? depotAccent.withValues(alpha: 0.16) : depotPanelAlt.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _applyTemplate(template),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: selected ? depotAccent : depotLineDim),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    template.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: depotText,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${template.type}${template.builtIn ? ' · 内置' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted),
                                  ),
                                  if ((template.description ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      template.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: _siteController,
                    style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                    decoration: depotInputDecoration('网站名称', hint: 'example.com', icon: Icons.language),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: TextField(
                      controller: _configController,
                      scrollController: _configScrollController,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        color: Color(0xffd6eadf),
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.45,
                      ),
                      decoration: depotInputDecoration('配置内容', hint: '选择左侧模板后生成配置，或直接输入配置内容')
                          .copyWith(alignLabelWithHint: true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          style: depotOutlinedButtonStyle(),
          child: const Text('取消'),
        ),
        if (hasPlaceholders)
          FilledButton.icon(
            onPressed: _saving ? null : _saveAsTemplate,
            icon: const Icon(Icons.bookmark_add_outlined, size: 16),
            label: const Text('保存为模版'),
            style: depotFilledButtonStyle(),
          )
        else
          FilledButton.icon(
            onPressed: _saving ? null : _saveSite,
            icon: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined, size: 16),
            label: const Text('保存'),
            style: depotFilledButtonStyle(),
          ),
      ],
    );
  }

  Future<void> _applyTemplate(NginxTemplateDefinition template) async {
    final placeholders = _extractPlaceholders(template.content);
    var content = template.content;
    if (placeholders.isNotEmpty) {
      final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _TemplateVariablesDialog(placeholders: placeholders),
      );
      if (values == null) {
        return;
      }
      for (final entry in values.entries) {
        content = content.replaceAll(RegExp(r'\{\{\s*' + RegExp.escape(entry.key) + r'\s*\}\}'), entry.value);
      }
      if (_siteController.text.trim().isEmpty && (values['domain'] ?? '').isNotEmpty) {
        _siteController.text = values['domain']!;
      }
    }
    setState(() {
      _selectedTemplateId = template.id;
      _configController.text = content;
    });
  }

  List<String> _extractPlaceholders(String content) {
    final placeholders = <String>{};
    for (final match in RegExp(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}').allMatches(content)) {
      placeholders.add(match.group(1)!);
    }
    final sorted = placeholders.toList()..sort();
    return sorted;
  }

  Future<void> _saveAsTemplate() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SaveTemplateDialog(
        controller: widget.controller,
        content: _configController.text,
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveSite() async {
    final site = _siteController.text.trim();
    if (site.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    await widget.controller.createNginxSite(siteName: site, config: _configController.text);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }
}

class _TemplateVariablesDialog extends StatefulWidget {
  const _TemplateVariablesDialog({required this.placeholders});

  final List<String> placeholders;

  @override
  State<_TemplateVariablesDialog> createState() => _TemplateVariablesDialogState();
}

class _TemplateVariablesDialogState extends State<_TemplateVariablesDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final placeholder in widget.placeholders) placeholder: TextEditingController(text: _defaultValue(placeholder)),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: depotPanel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: depotLine),
      ),
      title: Text(
        '填写占位符',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: depotText, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final placeholder in widget.placeholders) ...[
              TextField(
                controller: _controllers[placeholder],
                autofocus: placeholder == widget.placeholders.first,
                style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                decoration: depotInputDecoration(_labelFor(placeholder), hint: placeholder, icon: Icons.tune),
              ),
              if (placeholder != widget.placeholders.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: depotOutlinedButtonStyle(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop({
              for (final entry in _controllers.entries) entry.key: entry.value.text.trim(),
            });
          },
          style: depotFilledButtonStyle(),
          child: const Text('确认'),
        ),
      ],
    );
  }

  String _labelFor(String placeholder) {
    return switch (placeholder) {
      'domain' => '域名',
      'root_path' => '网站根目录',
      'upstream_host' => '后端地址',
      'upstream_port' => '后端端口',
      _ => placeholder,
    };
  }

  String _defaultValue(String placeholder) {
    return switch (placeholder) {
      'root_path' => '/var/www/html',
      'upstream_host' => '127.0.0.1',
      'upstream_port' => '3000',
      _ => '',
    };
  }
}

class _SaveTemplateDialog extends StatefulWidget {
  const _SaveTemplateDialog({
    required this.controller,
    required this.content,
  });

  final NginxCubit controller;
  final String content;

  @override
  State<_SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends State<_SaveTemplateDialog> {
  final _nameController = TextEditingController();
  final _typeController = TextEditingController(text: '自定义');
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: depotPanel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: depotLine),
      ),
      title: Text(
        '保存模板',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: depotText, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
              decoration: depotInputDecoration('模板名称', hint: 'Node 反向代理', icon: Icons.badge_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _typeController,
              style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
              decoration: depotInputDecoration('类型', hint: '反向代理', icon: Icons.category_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
              decoration: depotInputDecoration('说明', hint: '用于 127.0.0.1:3000', icon: Icons.notes_outlined),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: depotOutlinedButtonStyle(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            await widget.controller.saveWebsiteTemplate(
              name: _nameController.text,
              type: _typeController.text,
              description: _descriptionController.text,
              content: widget.content,
            );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          style: depotFilledButtonStyle(),
          child: const Text('确认'),
        ),
      ],
    );
  }
}

class _SiteConfigDialog extends StatefulWidget {
  const _SiteConfigDialog({
    required this.controller,
    required this.site,
  });

  final NginxCubit controller;
  final NginxSite site;

  @override
  State<_SiteConfigDialog> createState() => _SiteConfigDialogState();
}

class _SiteConfigDialogState extends State<_SiteConfigDialog> {
  final _configController = TextEditingController();
  final _configScrollController = ScrollController();
  final _resultScrollController = ScrollController();
  late Future<String?> _configFuture;
  String _result = '';
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _configFuture = widget.controller.readNginxSiteConfig(widget.site.name);
  }

  @override
  void dispose() {
    _configController.dispose();
    _configScrollController.dispose();
    _resultScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: depotPanel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: depotLine),
      ),
      title: Text(
        '${widget.site.name} 配置',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: depotText, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 760,
        height: 560,
        child: FutureBuilder<String?>(
          future: _configFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (snapshot.data == null && _configController.text.isEmpty) {
              return Center(
                child: Text('读取配置失败', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted)),
              );
            }
            if (_configController.text.isEmpty && snapshot.data != null) {
              _configController.text = snapshot.data!;
            }
            return Column(
              children: [
                Expanded(
                  child: TextField(
                    controller: _configController,
                    scrollController: _configScrollController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      color: Color(0xffd6eadf),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.45,
                    ),
                    decoration: depotInputDecoration('配置内容').copyWith(alignLabelWithHint: true),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  height: 92,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: depotTerminal,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: depotLineDim),
                  ),
                  child: DepotScrollbar(
                    controller: _resultScrollController,
                    child: SingleChildScrollView(
                      controller: _resultScrollController,
                      child: SelectableText(
                        _result.isEmpty ? '语法检查和保存结果会显示在这里。' : _result,
                        style: TextStyle(
                          color: _result.isEmpty ? depotMuted : const Color(0xffd6eadf),
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          style: depotOutlinedButtonStyle(),
          child: const Text('取消'),
        ),
        OutlinedButton.icon(
          onPressed: _running ? null : _testConfig,
          icon: _running
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check, size: 16),
          label: const Text('语法检查'),
          style: depotOutlinedButtonStyle(),
        ),
        FilledButton.icon(
          onPressed: _running ? null : _saveConfig,
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('保存'),
          style: depotFilledButtonStyle(),
        ),
      ],
    );
  }

  Future<void> _testConfig() async {
    setState(() {
      _running = true;
      _result = '';
    });
    final result = await widget.controller.testNginxSiteConfig(
      siteName: widget.site.name,
      config: _configController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _running = false;
      _result = result?.output.trim().isEmpty == true ? '语法检查通过' : (result?.output ?? '语法检查失败');
    });
  }

  Future<void> _saveConfig() async {
    setState(() {
      _running = true;
      _result = '';
    });
    final result = await widget.controller.saveNginxSiteConfig(
      siteName: widget.site.name,
      config: _configController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _running = false;
      _result = result?.output.trim().isEmpty == true ? '保存成功' : (result?.output ?? '保存失败');
    });
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: disabled ? null : onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: depotText,
        disabledForegroundColor: depotMuted.withValues(alpha: 0.5),
        side: const BorderSide(color: depotLine),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
