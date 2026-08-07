import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

class JournalctlCommand extends Command {
  const JournalctlCommand._({
    required this.summary,
    required this.text,
  });

  factory JournalctlCommand.unit(String unit, {int lines = 80, bool noPager = true}) {
    final pagerArg = noPager ? ' --no-pager' : '';
    return JournalctlCommand._(
      summary: '查看服务日志',
      text: 'journalctl -u ${shellQuote(unit)}$pagerArg -n $lines',
    );
  }

  @override
  final String summary;

  @override
  final String text;
}
