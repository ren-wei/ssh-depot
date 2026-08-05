class SshCommand {
  const SshCommand({
    required this.command,
    required this.summary,
    this.timeout,
  });

  final String command;
  final String summary;
  final Duration? timeout;
}
