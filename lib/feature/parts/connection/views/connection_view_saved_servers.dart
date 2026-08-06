part of 'connection_view.dart';

class _SavedServersPanel extends StatelessWidget {
  const _SavedServersPanel({
    required this.servers,
    required this.disabled,
    required this.onSelect,
    required this.onCreate,
    required this.onConnect,
    required this.onCopyAuthorizationCommand,
  });

  final List<ServerProfile> servers;
  final bool disabled;
  final ValueChanged<ServerProfile> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<ServerProfile> onConnect;
  final VoidCallback onCopyAuthorizationCommand;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('已保存的服务器', style: _titleStyle(context)),
          const SizedBox(height: 4),
          Text('点击即可填入表单', style: _captionStyle(context)),
          const SizedBox(height: 18),
          if (servers.isEmpty)
            const _EmptySavedServers()
          else
            for (final server in servers.take(5)) ...[
              _ServerTile(
                server: server,
                disabled: disabled,
                isDefault: servers.first == server,
                onSelect: () => onSelect(server),
                onConnect: () => onConnect(server),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 58),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: disabled ? null : onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增服务器'),
              style: _outlinedButtonStyle(),
            ),
          ),
          const SizedBox(height: 14),
          _AuthorizationHelpBox(
            isRunning: disabled,
            onCopyAuthorizationCommand: onCopyAuthorizationCommand,
          ),
        ],
      ),
    );
  }
}

class _AuthorizationHelpBox extends StatelessWidget {
  const _AuthorizationHelpBox({
    required this.isRunning,
    required this.onCopyAuthorizationCommand,
  });

  final bool isRunning;
  final VoidCallback onCopyAuthorizationCommand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xff071a11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lineDim),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final copyButton = OutlinedButton.icon(
            onPressed: isRunning ? null : onCopyAuthorizationCommand,
            icon: const Icon(Icons.copy, size: 16),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('复制授权命令'),
            ),
            style: _outlinedButtonStyle().copyWith(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          );
          final description = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.key_outlined, color: _accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '首次连接需要先授权本机公钥',
                      style: _titleStyle(context).copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '复制命令后，在目标服务器当前填写的 SSH 用户下执行；完成后回到这里点击“测试连接”。',
                      style: _captionStyle(context).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                description,
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: copyButton,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: description),
              const SizedBox(width: 12),
              copyButton,
            ],
          );
        },
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.server,
    required this.disabled,
    required this.isDefault,
    required this.onSelect,
    required this.onConnect,
  });

  final ServerProfile server;
  final bool disabled;
  final bool isDefault;
  final VoidCallback onSelect;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final name = server.name.isEmpty ? server.host : server.name;
    return Material(
      color: isDefault ? _panelAlt : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: disabled ? null : onSelect,
        onDoubleTap: disabled ? null : onConnect,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isDefault ? _line : _lineDim),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isDefault ? _accent : _muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      server.target,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _captionStyle(context),
                    ),
                    if (server.remark != null && server.remark!.trim().isNotEmpty)
                      Text(
                        server.remark!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _captionStyle(context),
                      ),
                  ],
                ),
              ),
              if (isDefault)
                SizedBox(
                  height: 28,
                  child: FilledButton(
                    onPressed: disabled ? null : onConnect,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xff08321f),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('默认'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
