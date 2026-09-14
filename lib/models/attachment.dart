/// File attachment stored locally or on R2 bucket.
class Attachment {
  final int id;
  final int seriesId;
  final String filePath;
  final String fileName;
  final int? fileSize;
  final String? createdAt;

  const Attachment({
    required this.id,
    required this.seriesId,
    required this.filePath,
    required this.fileName,
    this.fileSize,
    this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      seriesId: json['series_id'] is int
          ? json['series_id']
          : int.tryParse(json['series_id']?.toString() ?? '0') ?? 0,
      filePath: json['file_path']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      fileSize: json['file_size'] is int
          ? json['file_size']
          : int.tryParse(json['file_size']?.toString() ?? ''),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'series_id': seriesId,
        'file_path': filePath,
        'file_name': fileName,
        'file_size': fileSize,
        'created_at': createdAt,
      };
}
