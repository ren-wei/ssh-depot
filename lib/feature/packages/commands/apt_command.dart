import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

class AptCommand implements Command {
  const AptCommand._({
    required this.summary,
    required this.text,
  });

  factory AptCommand.update() {
    return const AptCommand._(
      summary: '更新软件源',
      text: 'apt update',
    );
  }

  factory AptCommand.install(String packageName) {
    return AptCommand._(
      summary: '安装软件包',
      text: 'apt install -y ${shellQuote(packageName)}',
    );
  }

  factory AptCommand.remove(String packageName) {
    return AptCommand._(
      summary: '卸载软件包',
      text: 'apt remove -y ${shellQuote(packageName)}',
    );
  }

  @override
  final String summary;

  @override
  final String text;
}
