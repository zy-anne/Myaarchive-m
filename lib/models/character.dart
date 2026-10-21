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
    Object? volumeAppearances = _unset,
    Object? notes = _unset,
    Object? profileImagePath = _unset,
    Object? statusRole = _unset,
    Object? overallVibes = _unset,
    Object? appearsVsReality = _unset,
    Object? appearsText = _unset,
    Object? realityText = _unset,
    Object? personality = _unset,
    Object? age = _unset,
    Object? lifeStatus = _unset,
  }) {
    return Character(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      name: name ?? this.name,
      role: role ?? this.role,
      volumeAppearances: identical(volumeAppearances, _unset) ? this.volumeAppearances : volumeAppearances as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      profileImagePath: identical(profileImagePath, _unset) ? this.profileImagePath : profileImagePath as String?,
      statusRole: identical(statusRole, _unset) ? this.statusRole : statusRole as String?,
      overallVibes: identical(overallVibes, _unset) ? this.overallVibes : overallVibes as String?,
      appearsVsReality: identical(appearsVsReality, _unset) ? this.appearsVsReality : appearsVsReality as String?,
      appearsText: identical(appearsText, _unset) ? this.appearsText : appearsText as String?,
      realityText: identical(realityText, _unset) ? this.realityText : realityText as String?,
      personality: identical(personality, _unset) ? this.personality : personality as String?,
      age: identical(age, _unset) ? this.age : age as String?,
      lifeStatus: identical(lifeStatus, _unset) ? this.lifeStatus : lifeStatus as String?,
    );
  }
}

/// Sentinel so copyWith can distinguish "not passed" from an explicit null.
const Object _unset = Object();
