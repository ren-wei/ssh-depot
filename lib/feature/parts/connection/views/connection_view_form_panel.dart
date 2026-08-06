part of 'connection_view.dart';

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({
    required this.nameController,
    required this.hostController,
    required this.userController,
    required this.isRunning,
    required this.testSucceeded,
    required this.hostError,
    required this.userError,
    required this.terminalText,
    required this.onSubmitted,
    required this.onTest,
    required this.onConnect,
    required this.onSave,
    required this.onCopyTroubleshootCommand,
  });

  final TextEditingController nameController;
  final TextEditingController hostController;
  final TextEditingController userController;
  final bool isRunning;
  final bool? testSucceeded;
  final String? hostError;
  final String? userError;
  final String terminalText;
  final VoidCallback onSubmitted;
  final VoidCallback onTest;
  final VoidCallback onConnect;
  final VoidCallback onSave;
  final VoidCallback onCopyTroubleshootCommand;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('连接信息', style: _titleStyle(context)),
          const SizedBox(height: 4),
          Text('仅支持密钥认证，用户名默认 root，可按服务器配置修改', style: _captionStyle(context)),
          const SizedBox(height: 22),
          const _FieldLabel('服务器名称'),
          const SizedBox(height: 7),
          _DarkTextField(
            controller: nameController,
            hintText: '请输入服务器名称',
            enabled: !isRunning,
          ),
          const SizedBox(height: 14),
          const _FieldLabel('主机 / 别名'),
          const SizedBox(height: 7),
          _DarkTextField(
            controller: hostController,
            hintText: '1.2.3.4',
            enabled: !isRunning,
            errorText: hostError,
            onSubmitted: (_) => onSubmitted(),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('用户名'),
          const SizedBox(height: 7),
          _DarkTextField(
            controller: userController,
            hintText: 'root',
            enabled: !isRunning,
            errorText: userError,
            onSubmitted: (_) => onSubmitted(),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: isRunning ? null : onTest,
                  icon: _PulseDot(
                    color: isRunning
                        ? Color(0xffffcf63)
                        : switch (testSucceeded) {
                            true => _accent,
                            false => Color(0xffff6d92),
                            null => _muted,
                          },
                  ),
                  label: Text(isRunning ? '连接中' : '测试连接'),
                  style: _outlinedButtonStyle(),
                ),
              ),
              SizedBox(
                height: 44,
                child: testSucceeded == false
                    ? FilledButton.icon(
                        onPressed: isRunning ? null : onCopyTroubleshootCommand,
                        icon: const Icon(Icons.manage_search, size: 18),
                        label: const Text('复制排查命令'),
                        style: _filledConnectButtonStyle(),
                      )
                    : FilledButton(
                        onPressed: isRunning ? null : onConnect,
                        style: _filledConnectButtonStyle(),
                        child: Text(isRunning ? '连接中' : '开始连接'),
                      ),
              ),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: isRunning ? null : onSave,
                  style: _outlinedButtonStyle(),
                  child: const Text('保存配置'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TerminalOutputBox(text: terminalText),
        ],
      ),
    );
  }
}
