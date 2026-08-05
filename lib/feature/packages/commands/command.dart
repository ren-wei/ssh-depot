abstract interface class Command {
  String get summary;
  String get text;
}

class CommandSequence implements Command {
  const CommandSequence({
    required this.commands,
    required this.summary,
    this.operator = '&&',
  });

  final List<Command> commands;

  @override
  final String summary;

  final String operator;

  @override
  String get text => commands.map((command) => command.text).join(' $operator ');
}

class CommandWithSummary implements Command {
  const CommandWithSummary({
    required this.command,
    required this.summary,
  });

  final Command command;

  @override
  final String summary;

  @override
  String get text => command.text;
}
