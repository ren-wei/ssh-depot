class TemplateRenderer {
  const TemplateRenderer();

  String render({
    required String template,
    required Map<String, Object?> variables,
  }) {
    var result = template;
    for (final entry in variables.entries) {
      result = result.replaceAll(
        '{{${entry.key}}}',
        entry.value?.toString() ?? '',
      );
    }
    return result;
  }
}
