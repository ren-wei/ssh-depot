import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

class FindCommand extends Command {
  const FindCommand._({
    required this.summary,
    required this.text,
  });

  factory FindCommand.files(String path, {int maxDepth = 1, bool printBasename = true, bool ignoreErrors = true}) {
    return FindCommand._(
      summary: '查找文件',
      text: _text(
        path: path,
        maxDepth: maxDepth,
        typeExpression: '-type f',
        printBasename: printBasename,
        ignoreErrors: ignoreErrors,
      ),
    );
  }

  factory FindCommand.filesOrLinks(String path,
      {int maxDepth = 1, bool printBasename = true, bool ignoreErrors = true}) {
    return FindCommand._(
      summary: '查找文件或链接',
      text: _text(
        path: path,
        maxDepth: maxDepth,
        typeExpression: r'\( -type f -o -type l \)',
        printBasename: printBasename,
        ignoreErrors: ignoreErrors,
      ),
    );
  }

  @override
  final String summary;

  @override
  final String text;

  static String _text({
    required String path,
    required int maxDepth,
    required String typeExpression,
    required bool printBasename,
    required bool ignoreErrors,
  }) {
    final printArg = printBasename ? '-printf "%f\\n"' : '-print';
    final errorArg = ignoreErrors ? ' 2>/dev/null || true' : '';
    return 'find ${shellQuote(path)} -maxdepth $maxDepth $typeExpression $printArg$errorArg';
  }
}
