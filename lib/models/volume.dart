/// Volume item model belonging to a Series.
class Volume {
  final int id;
  final int seriesId;
  final int volumeNumber;
  final String? title;
  final String? chapterRange;
  final int? chapterCount;
  final String? thoughts;
  final String? chapterNotes;
  final String? coverImagePath;
  final String? dateRead;
  final String? publishedDate;

  const Volume({
    required this.id,
    required this.seriesId,
    required this.volumeNumber,
    this.title,
    this.chapterRange,
    this.chapterCount,
    this.thoughts,
    this.chapterNotes,
    this.coverImagePath,
    this.dateRead,
    this.publishedDate,
  });

  factory Volume.fromJson(Map<String, dynamic> json) {
    return Volume(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      seriesId: json['series_id'] is int
          ? json['series_id']
          : int.tryParse(json['series_id'].toString()) ?? 0,
      volumeNumber: json['volume_number'] is int
          ? json['volume_number']
          : int.tryParse(json['volume_number'].toString()) ?? 1,
      title: json['title']?.toString(),
      chapterRange: json['chapter_range']?.toString(),
      chapterCount: json['chapter_count'] is int
          ? json['chapter_count']
          : int.tryParse(json['chapter_count']?.toString() ?? ''),
      thoughts: json['thoughts']?.toString(),
      chapterNotes: json['chapter_notes']?.toString(),
      coverImagePath: json['cover_image_path']?.toString(),
      dateRead: json['date_read']?.toString(),
      publishedDate: json['published_date']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'series_id': seriesId,
        'volume_number': volumeNumber,
        'title': title,
        'chapter_range': chapterRange,
        'chapter_count': chapterCount,
        'thoughts': thoughts,
        'chapter_notes': chapterNotes,
        'cover_image_path': coverImagePath,
        'date_read': dateRead,
        'published_date': publishedDate,
      };

  Volume copyWith({
    int? id,
    int? seriesId,
    int? volumeNumber,
    String? title,
    String? chapterRange,
    int? chapterCount,
    String? thoughts,
    String? chapterNotes,
    String? coverImagePath,
    String? dateRead,
    String? publishedDate,
  }) {
    return Volume(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      volumeNumber: volumeNumber ?? this.volumeNumber,
      title: title ?? this.title,
      chapterRange: chapterRange ?? this.chapterRange,
      chapterCount: chapterCount ?? this.chapterCount,
      thoughts: thoughts ?? this.thoughts,
      chapterNotes: chapterNotes ?? this.chapterNotes,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      dateRead: dateRead ?? this.dateRead,
      publishedDate: publishedDate ?? this.publishedDate,
    );
  }
}
