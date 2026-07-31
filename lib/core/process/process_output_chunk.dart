class ProcessOutputChunk {
  const ProcessOutputChunk({required this.text, required this.isStdErr});

  final String text;
  final bool isStdErr;
}
