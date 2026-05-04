class TemplateFolderNode {
  const TemplateFolderNode({
    required this.name,
    required this.relativePath,
    this.children = const [],
  });

  final String name;
  final String relativePath;
  final List<TemplateFolderNode> children;

  TemplateFolderNode copyWith({
    String? name,
    String? relativePath,
    List<TemplateFolderNode>? children,
  }) {
    return TemplateFolderNode(
      name: name ?? this.name,
      relativePath: relativePath ?? this.relativePath,
      children: children ?? this.children,
    );
  }
}
