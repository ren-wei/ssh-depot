import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

class RmCommand implements Command {
  const RmCommand._({
    required this.summary,
    required this.text,
  });

  factory RmCommand.files(List<String> paths, {bool force = true}) {
    final flagText = force ? ' -f' : '';
    return RmCommand._(
      summary: '删除文件',
      text: 'rm$flagText ${paths.map(shellQuote).join(' ')}',
    );
  }

  @override
  final String summary;

  @override
  final String text;
}
