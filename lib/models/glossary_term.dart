/// In-world glossary term and definition for a series.
class GlossaryTerm {
  final int id;
  final int seriesId;
  final String term;
  final String? definition;

  const GlossaryTerm({
    required this.id,
    required this.seriesId,
    required this.term,
    this.definition,
  });

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) {
    return GlossaryTerm(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      seriesId: json['series_id'] is int
          ? json['series_id']
          : int.tryParse(json['series_id']?.toString() ?? '0') ?? 0,
      term: json['term']?.toString() ?? '',
      definition: json['definition']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'series_id': seriesId,
        'term': term,
        'definition': definition,
      };

  GlossaryTerm copyWith({
    int? id,
    int? seriesId,
    String? term,
    String? definition,
  }) {
    return GlossaryTerm(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      term: term ?? this.term,
      definition: definition ?? this.definition,
    );
  }
}
