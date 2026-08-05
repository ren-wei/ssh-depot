import 'package:ssh_depot/feature/packages/commands/command.dart';
import 'package:ssh_depot/feature/utils/shell_quote.dart';

class EchoCommand implements Command {
  const EchoCommand(
    this.value, {
    this.summary = 'Echo',
  });

  final String value;

  @override
  final String summary;

  @override
  String get text => 'echo ${shellQuote(value)}';
}
