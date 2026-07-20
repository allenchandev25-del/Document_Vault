class VaultItem {
  final String id;
  final String originalName;
  final String fileExtension;
  final int sizeBytes;
  final DateTime addedDate;
  final String category;
  final String encryptedFileName;
  final List<String> tags;

  VaultItem({
    required this.id,
    required this.originalName,
    required this.fileExtension,
    required this.sizeBytes,
    required this.addedDate,
    required this.category,
    required this.encryptedFileName,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalName': originalName,
      'fileExtension': fileExtension,
      'sizeBytes': sizeBytes,
      'addedDate': addedDate.toIso8601String(),
      'category': category,
      'encryptedFileName': encryptedFileName,
      'tags': tags,
    };
  }

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    final tagsJson = json['tags'] as List<dynamic>?;
    final List<String> loadedTags = tagsJson != null
        ? tagsJson.map((e) => e.toString()).toList()
        : [];
    return VaultItem(
      id: json['id'] as String,
      originalName: json['originalName'] as String,
      fileExtension: json['fileExtension'] as String,
      sizeBytes: json['sizeBytes'] as int,
      addedDate: DateTime.parse(json['addedDate'] as String),
      category: json['category'] as String,
      encryptedFileName: json['encryptedFileName'] as String,
      tags: loadedTags,
    );
  }
}
