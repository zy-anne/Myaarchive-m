/// Inter-character relationship model.
class Relationship {
  final int id;
  final int fromCharacterId;
  final int toCharacterId;
  final String type;
  final String? label;
  final bool isBidirectional;
  final String? notes;

  // Joined character display names
  final String? fromCharacterName;
  final String? toCharacterName;
  final String? fromCharacterImage;
  final String? toCharacterImage;

  const Relationship({
    required this.id,
    required this.fromCharacterId,
    required this.toCharacterId,
    this.type = 'Friend',
    this.label,
    this.isBidirectional = true,
    this.notes,
    this.fromCharacterName,
    this.toCharacterName,
    this.fromCharacterImage,
    this.toCharacterImage,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) {
    final bidiRaw = json['is_bidirectional'];
    final isBidi = bidiRaw == null || bidiRaw == 1 || bidiRaw == true || bidiRaw == '1';

    return Relationship(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      fromCharacterId: json['from_character_id'] is int
          ? json['from_character_id']
          : int.tryParse(json['from_character_id'].toString()) ?? 0,
      toCharacterId: json['to_character_id'] is int
          ? json['to_character_id']
          : int.tryParse(json['to_character_id'].toString()) ?? 0,
      type: json['type']?.toString() ?? 'Friend',
      label: json['label']?.toString(),
      isBidirectional: isBidi,
      notes: json['notes']?.toString(),
      fromCharacterName: json['from_character_name']?.toString(),
      toCharacterName: json['to_character_name']?.toString(),
      fromCharacterImage: json['from_character_image']?.toString(),
      toCharacterImage: json['to_character_image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'from_character_id': fromCharacterId,
        'to_character_id': toCharacterId,
        'type': type,
        'label': label,
        'is_bidirectional': isBidirectional ? 1 : 0,
        'notes': notes,
      };
}
