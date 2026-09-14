/// Character model belonging to a Series with rich personality details.
class Character {
  final int id;
  final int seriesId;
  final String name;
  final String role;
  final String? volumeAppearances;
  final String? notes;
  final String? profileImagePath;

  // Character Detail Expansion Fields
  final String? statusRole;
  final String? overallVibes;
  final String? appearsVsReality;
  final String? appearsText;
  final String? realityText;
  final String? personality;
  final String? age;
  final String? lifeStatus;

  const Character({
    required this.id,
    required this.seriesId,
    required this.name,
    this.role = 'Side',
    this.volumeAppearances,
    this.notes,
    this.profileImagePath,
    this.statusRole,
    this.overallVibes,
    this.appearsVsReality,
    this.appearsText,
    this.realityText,
    this.personality,
    this.age,
    this.lifeStatus,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      seriesId: json['series_id'] is int
          ? json['series_id']
          : int.tryParse(json['series_id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Unnamed',
      role: json['role']?.toString() ?? 'Side',
      volumeAppearances: json['volume_appearances']?.toString(),
      notes: json['notes']?.toString(),
      profileImagePath: json['profile_image_path']?.toString(),
      statusRole: json['status_role']?.toString(),
      overallVibes: json['overall_vibes']?.toString(),
      appearsVsReality: json['appears_vs_reality']?.toString(),
      appearsText: json['appears_text']?.toString(),
      realityText: json['reality_text']?.toString(),
      personality: json['personality']?.toString(),
      age: json['age']?.toString(),
      lifeStatus: json['life_status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'series_id': seriesId,
        'name': name,
        'role': role,
        'volume_appearances': volumeAppearances,
        'notes': notes,
        'profile_image_path': profileImagePath,
        'status_role': statusRole,
        'overall_vibes': overallVibes,
        'appears_vs_reality': appearsVsReality,
        'appears_text': appearsText,
        'reality_text': realityText,
        'personality': personality,
        'age': age,
        'life_status': lifeStatus,
      };

  Character copyWith({
    int? id,
    int? seriesId,
    String? name,
    String? role,
    String? volumeAppearances,
    String? notes,
    String? profileImagePath,
    String? statusRole,
    String? overallVibes,
    String? appearsVsReality,
    String? appearsText,
    String? realityText,
    String? personality,
    String? age,
    String? lifeStatus,
  }) {
    return Character(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      name: name ?? this.name,
      role: role ?? this.role,
      volumeAppearances: volumeAppearances ?? this.volumeAppearances,
      notes: notes ?? this.notes,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      statusRole: statusRole ?? this.statusRole,
      overallVibes: overallVibes ?? this.overallVibes,
      appearsVsReality: appearsVsReality ?? this.appearsVsReality,
      appearsText: appearsText ?? this.appearsText,
      realityText: realityText ?? this.realityText,
      personality: personality ?? this.personality,
      age: age ?? this.age,
      lifeStatus: lifeStatus ?? this.lifeStatus,
    );
  }
}
