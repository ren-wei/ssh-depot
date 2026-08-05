class RemoteCommandResult {
  const RemoteCommandResult({
    required this.exitCode,
    required this.output,
  });

  final int exitCode;
  final String output;

  bool get succeeded => exitCode == 0;
}
