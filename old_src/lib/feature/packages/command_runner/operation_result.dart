class OperationResult {
  const OperationResult({required this.summary, required this.exitCode});

  final String summary;
  final int exitCode;

  bool get isSuccess => exitCode == 0;
}
