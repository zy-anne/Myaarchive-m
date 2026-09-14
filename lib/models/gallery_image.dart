/// Image item in a series gallery.
class GalleryImage {
  final int id;
  final int seriesId;
  final String imagePath;
  final String? caption;
  final int position;

  const GalleryImage({
    required this.id,
    required this.seriesId,
    required this.imagePath,
    this.caption,
    this.position = 0,
  });

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    return GalleryImage(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      seriesId: json['series_id'] is int
          ? json['series_id']
          : int.tryParse(json['series_id'].toString()) ?? 0,
      imagePath: json['image_path']?.toString() ?? '',
      caption: json['caption']?.toString(),
      position: json['position'] is int
          ? json['position']
          : int.tryParse(json['position'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'series_id': seriesId,
        'image_path': imagePath,
        'caption': caption,
        'position': position,
      };
}

