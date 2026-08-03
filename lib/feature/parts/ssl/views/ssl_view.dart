import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../classes/nginx_site.dart';
import '../../../components/app_scope.dart';
import '../../../components/app_shell.dart';
import '../../../components/depot_content.dart';
import '../../../components/depot_scrollbar.dart';
import '../../../components/depot_snack_bar.dart';
import '../../../cubits/app_controller.dart';

class SslView extends StatefulWidget {
  const SslView({super.key});

  @override
  State<SslView> createState() => _SslViewState();
}

class _SslViewState extends State<SslView> {
  final _domainsController = TextEditingController();
  final _emailController = TextEditingController();
  final _webrootController = TextEditingController(text: '/var/www/html');
  final _outputScrollController = ScrollController();
  bool _requestedInitialRefresh = false;
  bool _useWebroot = false;
  String _output = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (!_requestedInitialRefresh && controller.isConnected && controller.nginxCertificates.isEmpty) {
      _requestedInitialRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          controller.refreshNginxSites();
        }
      });
    }
  }

  @override
  void dispose() {
    _domainsController.dispose();
    _emailController.dispose();
    _webrootController.dispose();
    _outputScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final disabled = !controller.isConnected || controller.isRunning;
    final certificates = controller.nginxCertificates;

    return DepotContentPage(
      title: '证书管理',
      subtitle: '管理当前服务器上的 certbot 证书资产；网站列表只展示证书状态。',
      actions: [
        DepotStatusPill(
          label: controller.isRunning ? '执行中' : (controller.isConnected ? '就绪' : '未连接'),
          color: controller.isConnected ? depotAccent : depotYellow,
        ),
      ],
      children: [
        DepotPanel(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DepotSectionHeader(
                title: '申请证书',
                subtitle: '默认使用 Nginx 自动配置；多个域名可用逗号或空格分隔。',
                trailing: OutlinedButton.icon(
                  onPressed: disabled ? null : () => _run(controller.checkCertificateEnvironment),
                  icon: const Icon(Icons.health_and_safety_outlined, size: 18),
                  label: const Text('环境检查'),
                  style: depotOutlinedButtonStyle(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _domainsController,
                      style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                      decoration: depotInputDecoration('域名', hint: 'example.com, www.example.com', icon: Icons.public),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                      decoration: depotInputDecoration('邮箱', hint: 'admin@example.com', icon: Icons.mail_outline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilterChip(
                    selected: !_useWebroot,
                    onSelected: disabled ? null : (_) => setState(() => _useWebroot = false),
                    label: const Text('Nginx 自动配置'),
                    selectedColor: depotAccent,
                    backgroundColor: depotPanelAlt.withValues(alpha: depotMutedSurfaceStrongAlpha),
                    side: const BorderSide(color: depotLineDim),
                    labelStyle: TextStyle(
                      color: !_useWebroot ? const Color(0xff06311f) : depotText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilterChip(
                    selected: _useWebroot,
                    onSelected: disabled ? null : (_) => setState(() => _useWebroot = true),
                    label: const Text('Webroot'),
                    selectedColor: depotAccent,
                    backgroundColor: depotPanelAlt.withValues(alpha: depotMutedSurfaceStrongAlpha),
                    side: const BorderSide(color: depotLineDim),
                    labelStyle: TextStyle(
                      color: _useWebroot ? const Color(0xff06311f) : depotText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: disabled ? null : () => _confirmRequestCertificate(controller),
                    icon: controller.isRunning
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.verified_user_outlined, size: 18),
                    label: const Text('申请并配置 HTTPS'),
                    style: depotFilledButtonStyle(),
                  ),
                ],
              ),
              if (_useWebroot) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _webrootController,
                  style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                  decoration: depotInputDecoration('Webroot 路径', hint: '/var/www/html', icon: Icons.folder_outlined),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        DepotPanel(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DepotSectionHeader(
                title: '证书列表',
                subtitle: certificates.isEmpty ? '暂无证书，点击刷新读取 certbot 证书。' : '共 ${certificates.length} 个证书。',
                trailing: FilledButton.icon(
                  onPressed: disabled ? null : controller.refreshNginxSites,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('刷新'),
                  style: depotFilledButtonStyle(),
                ),
              ),
              const SizedBox(height: 18),
              DepotRow(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text('证书', style: depotMutedText(context))),
                    Expanded(flex: 2, child: Text('状态', style: depotMutedText(context))),
                    Expanded(flex: 5, child: Text('覆盖域名', style: depotMutedText(context))),
                    Expanded(flex: 5, child: Text('操作', textAlign: TextAlign.right, style: depotMutedText(context))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (certificates.isEmpty)
                DepotRow(
                  child: Text(
                    controller.isConnected ? '点击刷新读取证书列表' : '请先连接服务器',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted),
                  ),
                )
              else
                for (final certificate in certificates) ...[
                  _CertificateRow(
                    certificate: certificate,
                    disabled: disabled,
                    onAddDomain: () => _showAddDomainDialog(controller, certificate),
                    onRemoveDomain: () => _showRemoveDomainDialog(controller, certificate),
                    onDryRunRenew: () => _confirmAndRun(
                      title: '测试续期',
                      message:
                          '将执行 certbot renew --cert-name ${certificate.certName} --dry-run。此操作不会续期正式证书，但会模拟验证续期流程。',
                      action: () => controller.renewCertificate(certificate.certName, dryRun: true),
                    ),
                    onRenew: () => _confirmAndRun(
                      title: '续期证书',
                      message: '将执行 certbot renew --cert-name ${certificate.certName}。如果证书未到期，certbot 可能会提示无需续期。',
                      action: () => controller.renewCertificate(certificate.certName),
                    ),
                  ),
                  if (certificate != certificates.last) const SizedBox(height: 10),
                ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        _OutputPanel(
          output: _output,
          scrollController: _outputScrollController,
          onCopy: _output.trim().isEmpty ? null : () => _copyForAi(context),
        ),
      ],
    );
  }

  Future<void> _confirmRequestCertificate(AppController controller) {
    final domains = _domainsController.text.trim();
    final email = _emailController.text.trim();
    final webroot = _webrootController.text.trim();
    final parsedDomains = _parseInputDomains(domains);
    if (parsedDomains.isEmpty) {
      showDepotSnackBar(context, '请输入至少一个域名');
      return Future.value();
    }
    if (email.isEmpty) {
      showDepotSnackBar(context, '请输入邮箱');
      return Future.value();
    }
    if (_useWebroot && webroot.isEmpty) {
      showDepotSnackBar(context, '请输入 Webroot 路径');
      return Future.value();
    }
    return _confirmAndRun(
      title: '申请并配置 HTTPS',
      message: '将为 ${parsedDomains.join(' / ')} 申请证书。'
          '${_useWebroot ? '当前选择 Webroot 模式，certbot 不会自动修改 Nginx 配置。' : '当前允许 certbot 自动修改 Nginx 配置。'}'
          '请确认域名已解析到当前服务器，邮箱有效，并且 80/443 端口可访问。',
      action: () => controller.requestCertificate(
        domain: parsedDomains.join(' '),
        email: email,
        useWebroot: _useWebroot,
        webroot: webroot,
      ),
    );
  }

  Future<void> _confirmAndRun({
    required String title,
    required String message,
    required Future<RemoteCommandResult?> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: depotPanel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: depotLine),
        ),
        title: Text(title, style: const TextStyle(color: depotText, fontWeight: FontWeight.w900)),
        content: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted),
        ),
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
      ),
    );
    if (confirmed == true) {
      await _run(action);
    }
  }

  Future<void> _showAddDomainDialog(AppController controller, NginxCertificateInfo certificate) async {
    final plan = await showDialog<_CertificateDomainUpdatePlan>(
      context: context,
      builder: (context) => _AddDomainDialog(certificate: certificate),
    );
    if (plan == null || plan.domains.isEmpty) {
      return;
    }
    final nextDomains = {...certificate.domains, ...plan.domains}.toList();
    await _confirmAndRun(
      title: '添加域名',
      message: '添加域名会使用证书 ${certificate.certName} 和完整域名列表重新签发证书。'
          '${plan.autoConfigureNginx ? 'certbot 将被允许自动修改 Nginx 配置。' : 'certbot 不会自动修改 Nginx 配置，将使用 Webroot 验证。'}'
          '请确认新域名已解析到当前服务器，并且 80/443 端口可访问。',
      action: () => controller.updateCertificateDomains(
        certName: certificate.certName,
        domains: nextDomains,
        useWebroot: !plan.autoConfigureNginx,
        webroot: plan.webroot,
      ),
    );
  }

  Future<void> _showRemoveDomainDialog(AppController controller, NginxCertificateInfo certificate) async {
    final plan = await showDialog<_CertificateDomainUpdatePlan>(
      context: context,
      builder: (context) => _RemoveDomainDialog(certificate: certificate),
    );
    if (plan == null) {
      return;
    }
    await _confirmAndRun(
      title: '删除域名',
      message: '删除域名会使用剩余域名重新签发证书 ${certificate.certName}。'
          '${plan.autoConfigureNginx ? 'certbot 将被允许自动修改 Nginx 配置。' : 'certbot 不会自动修改 Nginx 配置，将使用 Webroot 验证。'}'
          '被删除的域名将不再被该证书覆盖，仍引用它的网站可能出现 HTTPS 证书不匹配。',
      action: () => controller.updateCertificateDomains(
        certName: certificate.certName,
        domains: plan.domains,
        useWebroot: !plan.autoConfigureNginx,
        webroot: plan.webroot,
      ),
    );
  }

  Future<void> _run(Future<RemoteCommandResult?> Function() action) async {
    setState(() => _output = '');
    final result = await action();
    if (!mounted) {
      return;
    }
    setState(() {
      _output =
          result?.output.trim().isEmpty == true ? (result!.succeeded ? '操作成功' : '操作失败') : (result?.output ?? '操作失败');
    });
  }

  Future<void> _copyForAi(BuildContext context) async {
    final content = '''
请分析下面这次 ssh-depot 证书管理命令输出，定位问题原因并给出修复建议：

```text
${_output.trimRight()}
```
''';
    await Clipboard.setData(ClipboardData(text: content.trim()));
    if (context.mounted) {
      showDepotSnackBar(context, '已复制证书命令输出和分析提示词');
    }
  }
}

class _CertificateRow extends StatelessWidget {
  const _CertificateRow({
    required this.certificate,
    required this.disabled,
    required this.onAddDomain,
    required this.onRemoveDomain,
    required this.onDryRunRenew,
    required this.onRenew,
  });

  final NginxCertificateInfo certificate;
  final bool disabled;
  final VoidCallback onAddDomain;
  final VoidCallback onRemoveDomain;
  final VoidCallback onDryRunRenew;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final color = _certificateColor(certificate.status);
    return DepotRow(
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                DepotDot(color: color, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        certificate.certName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: depotText,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        _dateLabel(certificate.expiresAt),
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: DepotStatusPill(label: certificate.statusLabel, color: color),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              certificate.domains.isEmpty ? '未知' : certificate.domains.join(' / '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 5,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _MiniAction(label: '添加域名', icon: Icons.add_link, disabled: disabled, onPressed: onAddDomain),
                _MiniAction(label: '删除域名', icon: Icons.link_off, disabled: disabled, onPressed: onRemoveDomain),
                _MiniAction(label: '测试续期', icon: Icons.science_outlined, disabled: disabled, onPressed: onDryRunRenew),
                _MiniAction(label: '续期', icon: Icons.refresh, disabled: disabled, onPressed: onRenew),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputPanel extends StatelessWidget {
  const _OutputPanel({
    required this.output,
    required this.scrollController,
    required this.onCopy,
  });

  final String output;
  final ScrollController scrollController;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return DepotPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: depotLineDim))),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 18, color: depotMuted),
                const SizedBox(width: 10),
                Text(
                  '证书命令输出',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: depotText,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy for ai'),
                  style: TextButton.styleFrom(
                    foregroundColor: depotText,
                    disabledForegroundColor: depotMuted.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 260,
            child: DepotScrollbar(
              controller: scrollController,
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SelectableText(
                    output.isEmpty ? '证书操作输出会显示在这里。' : output,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: output.isEmpty ? depotMuted : const Color(0xffd6eadf),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDomainDialog extends StatefulWidget {
  const _AddDomainDialog({required this.certificate});

  final NginxCertificateInfo certificate;

  @override
  State<_AddDomainDialog> createState() => _AddDomainDialogState();
}

class _AddDomainDialogState extends State<_AddDomainDialog> {
  final _domainsController = TextEditingController();
  final _webrootController = TextEditingController(text: '/var/www/html');
  bool _autoConfigureNginx = true;
  String? _error;

  @override
  void dispose() {
    _domainsController.dispose();
    _webrootController.dispose();
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
      title: const Text('添加域名', style: TextStyle(color: depotText, fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '将使用完整域名列表重新签发证书 ${widget.certificate.certName}。新增域名必须已解析到当前服务器。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _domainsController,
              autofocus: true,
              style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
              decoration: depotInputDecoration('新增域名', hint: 'api.example.com, cdn.example.com', icon: Icons.add_link),
            ),
            const SizedBox(height: 12),
            _AutoConfigureCheckbox(
              value: _autoConfigureNginx,
              onChanged: (value) => setState(() => _autoConfigureNginx = value),
            ),
            if (!_autoConfigureNginx) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _webrootController,
                style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                decoration: depotInputDecoration('Webroot 路径', hint: '/var/www/html', icon: Icons.folder_outlined),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: depotRed, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: depotOutlinedButtonStyle(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          style: depotFilledButtonStyle(),
          child: const Text('确认'),
        ),
      ],
    );
  }

  void _submit() {
    final domains = _parseInputDomains(_domainsController.text);
    if (domains.isEmpty) {
      setState(() => _error = '请输入至少一个新增域名');
      return;
    }
    if (!_autoConfigureNginx && _webrootController.text.trim().isEmpty) {
      setState(() => _error = '请输入 Webroot 路径');
      return;
    }
    Navigator.of(context).pop(
      _CertificateDomainUpdatePlan(
        domains: domains,
        autoConfigureNginx: _autoConfigureNginx,
        webroot: _webrootController.text.trim(),
      ),
    );
  }
}

class _RemoveDomainDialog extends StatefulWidget {
  const _RemoveDomainDialog({required this.certificate});

  final NginxCertificateInfo certificate;

  @override
  State<_RemoveDomainDialog> createState() => _RemoveDomainDialogState();
}

class _RemoveDomainDialogState extends State<_RemoveDomainDialog> {
  final _webrootController = TextEditingController(text: '/var/www/html');
  late final Set<String> _remainingDomains = widget.certificate.domains.toSet();
  bool _autoConfigureNginx = true;
  String? _error;

  @override
  void dispose() {
    _webrootController.dispose();
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
      title: const Text('删除域名', style: TextStyle(color: depotText, fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '取消勾选要从证书 ${widget.certificate.certName} 中移除的域名。此操作会用剩余域名重新签发证书。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: depotMuted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final domain in widget.certificate.domains)
              CheckboxListTile(
                value: _remainingDomains.contains(domain),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _remainingDomains.add(domain);
                    } else {
                      _remainingDomains.remove(domain);
                    }
                  });
                },
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: depotAccent,
                checkColor: const Color(0xff06311f),
                title: Text(domain, style: const TextStyle(color: depotText, fontWeight: FontWeight.w800)),
              ),
            const SizedBox(height: 8),
            _AutoConfigureCheckbox(
              value: _autoConfigureNginx,
              onChanged: (value) => setState(() => _autoConfigureNginx = value),
            ),
            if (!_autoConfigureNginx) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _webrootController,
                style: const TextStyle(color: depotText, fontWeight: FontWeight.w700),
                decoration: depotInputDecoration('Webroot 路径', hint: '/var/www/html', icon: Icons.folder_outlined),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: depotRed, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: depotOutlinedButtonStyle(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          style: depotFilledButtonStyle(),
          child: const Text('确认'),
        ),
      ],
    );
  }

  void _submit() {
    if (_remainingDomains.length == widget.certificate.domains.length) {
      setState(() => _error = '请选择至少一个要删除的域名');
      return;
    }
    if (_remainingDomains.isEmpty) {
      setState(() => _error = '证书至少需要保留一个域名');
      return;
    }
    if (!_autoConfigureNginx && _webrootController.text.trim().isEmpty) {
      setState(() => _error = '请输入 Webroot 路径');
      return;
    }
    Navigator.of(context).pop(
      _CertificateDomainUpdatePlan(
        domains: _remainingDomains.toList(),
        autoConfigureNginx: _autoConfigureNginx,
        webroot: _webrootController.text.trim(),
      ),
    );
  }
}

class _AutoConfigureCheckbox extends StatelessWidget {
  const _AutoConfigureCheckbox({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (value) => onChanged(value ?? false),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: depotAccent,
      checkColor: const Color(0xff06311f),
      title: const Text('允许 certbot 自动修改 Nginx 配置', style: TextStyle(color: depotText, fontWeight: FontWeight.w900)),
      subtitle: Text(
        value ? '将使用 certbot --nginx，可能更新 server 配置。' : '将使用 Webroot 验证，不自动修改 Nginx 配置。',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: depotMuted),
      ),
    );
  }
}

class _CertificateDomainUpdatePlan {
  const _CertificateDomainUpdatePlan({
    required this.domains,
    required this.autoConfigureNginx,
    required this.webroot,
  });

  final List<String> domains;
  final bool autoConfigureNginx;
  final String webroot;
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

Color _certificateColor(CertificateStatus status) {
  return switch (status) {
    CertificateStatus.valid => depotAccent,
    CertificateStatus.expiringSoon => depotYellow,
    CertificateStatus.expired => depotRed,
    CertificateStatus.missing => depotMuted,
    CertificateStatus.unknown => depotYellow,
  };
}

String _dateLabel(DateTime? value) {
  if (value == null) {
    return '到期时间未知';
  }
  String two(int number) => number.toString().padLeft(2, '0');
  return '到期 ${value.year}-${two(value.month)}-${two(value.day)}';
}

List<String> _parseInputDomains(String value) {
  return value
      .split(RegExp(r'[\s,]+'))
      .map((domain) => domain.trim())
      .where((domain) => domain.isNotEmpty)
      .toSet()
      .toList();
}
