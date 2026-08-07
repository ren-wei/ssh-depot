import 'package:ssh_depot/feature/classes/remote_command_result.dart';

abstract class Command {
  const Command();

  String get summary;
  String get text;

  Object? parse(RemoteCommandResult result) => null;
}

class CommandSequence extends Command {
  const CommandSequence({
    required this.commands,
    required this.summary,
    this.operator = '&&',
    this.parser,
  });

  final List<Command> commands;

  @override
  final String summary;

  final String operator;
  final Object? Function(RemoteCommandResult result)? parser;

  @override
  String get text => commands.map((command) => command.text).join(' $operator ');

  @override
  Object? parse(RemoteCommandResult result) => parser?.call(result);
}
