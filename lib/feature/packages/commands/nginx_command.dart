import 'package:ssh_depot/feature/packages/commands/command.dart';

class NginxCommand implements Command {
  const NginxCommand._({
    required this.summary,
    required this.text,
  });

  factory NginxCommand.test() {
    return const NginxCommand._(
      summary: '网站语法检查',
      text: 'nginx -t',
    );
  }

  @override
  final String summary;

  @override
  final String text;
}
