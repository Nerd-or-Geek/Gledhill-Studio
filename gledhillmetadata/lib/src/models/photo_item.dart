class PhotoItem {
  const PhotoItem({
    required this.path,
    required this.fileName,
    this.metadataSummary = const {},
    this.fullMetadata = const {},
    this.isSelected = false,
  });

  final String path;
  final String fileName;
  final Map<String, String> metadataSummary;
  final Map<String, String> fullMetadata;
  final bool isSelected;

  PhotoItem copyWith({
    String? path,
    String? fileName,
    Map<String, String>? metadataSummary,
    Map<String, String>? fullMetadata,
    bool? isSelected,
  }) {
    return PhotoItem(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      metadataSummary: metadataSummary ?? this.metadataSummary,
      fullMetadata: fullMetadata ?? this.fullMetadata,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
