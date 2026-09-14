/// Link or external bookmark attached to a series.
class LinkAttachment {
  final int id;
  final int seriesId;
  final String url;
  final String? label;
  final String? createdAt;

  const LinkAttachment({
    required this.id,
    required this.seriesId,
    required this.url,
    this.label,
    this.createdAt,
  });

  factory LinkAttachment.fromJson(Map<String, dynamic> json) {
    return LinkAttachment(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      seriesId: json['series_id'] is int
          ? json['series_id']
          : int.tryParse(json['series_id'].toString()) ?? 0,
      url: json['url']?.toString() ?? '',
      label: json['label']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'series_id': seriesId,
        'url': url,
        'label': label,
      };
}
