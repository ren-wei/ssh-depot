String shellQuote(String value) {
  return "'${value.replaceAll("'", "'\"'\"'")}'";
}
