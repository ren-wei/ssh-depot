class NginxTemplateDefinition {
  const NginxTemplateDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.content,
    this.description,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final String type;
  final String content;
  final String? description;
  final bool builtIn;
}
