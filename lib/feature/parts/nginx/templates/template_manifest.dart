class TemplateManifest {
  const TemplateManifest({
    required this.id,
    required this.name,
    required this.variables,
  });

  final String id;
  final String name;
  final List<TemplateVariable> variables;
}

class TemplateVariable {
  const TemplateVariable({
    required this.name,
    required this.type,
    required this.label,
  });

  final String name;
  final TemplateVariableType type;
  final String label;
}

enum TemplateVariableType { string, number, boolean }
