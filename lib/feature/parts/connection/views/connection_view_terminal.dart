part of 'connection_view.dart';

class _TerminalOutputBox extends StatefulWidget {
  const _TerminalOutputBox({required this.text});

  final String text;

  @override
  State<_TerminalOutputBox> createState() => _TerminalOutputBoxState();
}

class _TerminalOutputBoxState extends State<_TerminalOutputBox> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant _TerminalOutputBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final output = widget.text.trim().isEmpty ? '暂无输出' : widget.text.trimRight();
    return Container(
      width: double.infinity,
      height: 148,
      decoration: BoxDecoration(
        color: const Color(0xff020b07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lineDim),
      ),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _lineDim)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: _muted, size: 16),
                const SizedBox(width: 8),
                Text(
                  '终端',
                  style: _captionStyle(
                    context,
                  ).copyWith(color: _text, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.text.trim().isEmpty ? null : () => _copyForAi(context),
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy for ai'),
                  style: TextButton.styleFrom(
                    foregroundColor: _text,
                    disabledForegroundColor: _muted.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DepotScrollbar(
              controller: _scrollController,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 22,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SelectableText(
                          output,
                          style: TextStyle(
                            color: widget.text.trim().isEmpty ? _muted : const Color(0xffd6eadf),
                            fontFamily: 'monospace',
                            fontFamilyFallback: const [
                              'Noto Sans Mono CJK SC',
                              'Noto Sans CJK SC',
                              'Noto Sans CJK',
                              'WenQuanYi Micro Hei',
                            ],
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyForAi(BuildContext context) async {
    final block = _lastCommandBlock(widget.text);
    final content = '''
请分析下面这次 SSH 终端命令和输出，定位问题原因并给出修复建议：

```text
$block
```
''';
    await Clipboard.setData(ClipboardData(text: content.trim()));
    if (!context.mounted) {
      return;
    }
    showDepotSnackBar(context, '已复制最后一条命令和输出');
  }

  String _lastCommandBlock(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) {
      return '暂无输出';
    }
    final markerIndex = trimmed.lastIndexOf('\n\$ ');
    if (markerIndex >= 0) {
      return trimmed.substring(markerIndex + 1).trimRight();
    }
    if (trimmed.startsWith(r'$ ')) {
      return trimmed;
    }
    return trimmed;
  }
}
