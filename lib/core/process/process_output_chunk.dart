class ProcessOutputChunk {
  const ProcessOutputChunk({required this.text, required this.isStdErr, String? rawText}) : rawText = rawText ?? text;

  final String text;
  final String rawText;
  final bool isStdErr;
}
