import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

class LnCommand implements Command {
  const LnCommand._({
    required this.summary,
    required this.text,
  });

  factory LnCommand.symbolic({
    required String source,
    required String target,
    bool force = true,
    bool noDereferenceTarget = true,
  }) {
    final flags = 's${force ? 'f' : ''}${noDereferenceTarget ? 'n' : ''}';
    return LnCommand._(
      summary: '创建链接',
      text: 'ln -$flags ${shellQuote(source)} ${shellQuote(target)}',
    );
  }

  factory LnCommand.symbolicRaw({
    required String source,
    required String target,
    bool force = true,
    bool noDereferenceTarget = true,
  }) {
    final flags = 's${force ? 'f' : ''}${noDereferenceTarget ? 'n' : ''}';
    return LnCommand._(
      summary: '创建链接',
      text: 'ln -$flags $source ${shellQuote(target)}',
    );
  }

  @override
  final String summary;

  @override
  final String text;
}
