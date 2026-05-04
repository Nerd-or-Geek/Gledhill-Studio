class RenameConvention {
  const RenameConvention({
    required this.id,
    required this.name,
    required this.pattern,
    this.isFavorite = false,
    this.folderPath = '',
  });

  final String id;
  final String name;
  final String pattern;
  final bool isFavorite;
  final String folderPath;

  factory RenameConvention.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    return RenameConvention(
      id: (json['id'] as String?) ?? name,
      name: name,
      pattern: (json['pattern'] as String?) ?? '{year}-{month}-{day}_{sequence:3}',
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      folderPath: (json['folderPath'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isFavorite': isFavorite,
      'pattern': pattern,
    };
  }

  RenameConvention copyWith({
    String? id,
    String? name,
    String? pattern,
    bool? isFavorite,
    String? folderPath,
  }) {
    return RenameConvention(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      isFavorite: isFavorite ?? this.isFavorite,
      folderPath: folderPath ?? this.folderPath,
    );
  }
}
