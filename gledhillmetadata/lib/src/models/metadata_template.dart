class MetadataTemplate {
  const MetadataTemplate({
    required this.id,
    required this.name,
    this.isFavorite = false,
    this.folderPath = '',
    required this.fields,
  });

  final String id;
  final String name;
  final bool isFavorite;
  final String folderPath;
  final Map<String, String> fields;

  factory MetadataTemplate.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    return MetadataTemplate(
      id: (json['id'] as String?) ?? name,
      name: name,
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      folderPath: (json['folderPath'] as String?) ?? '',
      fields: Map<String, String>.from(json['fields'] as Map<dynamic, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isFavorite': isFavorite,
      'fields': fields,
    };
  }

  MetadataTemplate copyWith({
    String? id,
    String? name,
    bool? isFavorite,
    String? folderPath,
    Map<String, String>? fields,
  }) {
    return MetadataTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      isFavorite: isFavorite ?? this.isFavorite,
      folderPath: folderPath ?? this.folderPath,
      fields: fields ?? this.fields,
    );
  }
}
