String shellQuote(Object? value) {
  final text = value?.toString() ?? '';
  return "'${text.replaceAll("'", "'\"'\"'")}'";
}
