/// Library collection model (e.g. Manga, Light Novels, Webtoons, Books).
class Library {
  final int id;
  final String ownerId;
  final String name;
  final String icon;
  final String? iconImage;
  final int position;
  final int seriesCount;

  const Library({
    required this.id,
    required this.ownerId,
    required this.name,
    this.icon = 'grid',
    this.iconImage,
    this.position = 0,
    this.seriesCount = 0,
  });

  factory Library.fromJson(Map<String, dynamic> json) {
    return Library(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      ownerId: json['owner_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'grid',
      iconImage: json['icon_image']?.toString(),
      position: json['position'] is int
          ? json['position']
          : int.tryParse(json['position'].toString()) ?? 0,
      seriesCount: json['series_count'] is int
          ? json['series_count']
          : int.tryParse(json['series_count'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'icon': icon,
        'icon_image': iconImage,
        'position': position,
      };

  Library copyWith({
    int? id,
    String? ownerId,
    String? name,
    String? icon,
    String? iconImage,
    int? position,
    int? seriesCount,
  }) {
    return Library(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      iconImage: iconImage ?? this.iconImage,
      position: position ?? this.position,
      seriesCount: seriesCount ?? this.seriesCount,
    );
  }
}
