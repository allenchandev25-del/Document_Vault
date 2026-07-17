class VaultItem {
  final String id;
  final String originalName;
  final String fileExtension;
  final int sizeBytes;
  final DateTime addedDate;
  final String category;
  final String encryptedFileName;

  VaultItem({
    required this.id,
    required this.originalName,
    required this.fileExtension,
    required this.sizeBytes,
    required this.addedDate,
    required this.category,
    required this.encryptedFileName,
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
    };
  }

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      originalName: json['originalName'] as String,
      fileExtension: json['fileExtension'] as String,
      sizeBytes: json['sizeBytes'] as int,
      addedDate: DateTime.parse(json['addedDate'] as String),
      category: json['category'] as String,
      encryptedFileName: json['encryptedFileName'] as String,
    );
  }
}
