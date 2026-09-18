/// Umbrella "Series Group" (shared universe) models.
///
/// Mirrors `series_groups` / `series_group_items` from the Electron app's
/// data layer (see app.js's "Series Groups (Umbrella Groups / Shared
/// Universes)" section). A group links a set of member series/books
/// together — e.g. a shared universe, a main story + its spin-offs, or a
/// prequel/sequel pair — each tagged with a [groupRole].
library;

/// The fixed set of roles a member title can have within a group.
class GroupRoles {
  GroupRoles._();

  static const String mainStory = 'Main Story';
  static const String sideStory = 'Side Story';
  static const String prequel = 'Prequel';
  static const String sequel = 'Sequel';
  static const String spinOff = 'Spin-off';
  static const String companion = 'Companion';
  static const String shortStory = 'Short Story';
  static const String novella = 'Novella';

  static const List<String> all = [
    mainStory,
    sideStory,
    prequel,
    sequel,
    spinOff,
    companion,
    shortStory,
    novella,
  ];
}

/// One member title inside a [SeriesGroup], joined with enough of the
/// parent `series` row to render a "sub-book" card without a second query.
class SeriesGroupItem {
  final int seriesId;
  final String title;
  final String? coverImagePath;
  final String status;
  final String kind;
  final int? rating;
  final int volumeCount;
  final String groupRole;
  final int position;

  const SeriesGroupItem({
    required this.seriesId,
    required this.title,
    this.coverImagePath,
    this.status = 'Planning',
    this.kind = 'series',
    this.rating,
    this.volumeCount = 0,
    this.groupRole = GroupRoles.mainStory,
    this.position = 0,
  });

  factory SeriesGroupItem.fromJson(Map<String, dynamic> json) {
    return SeriesGroupItem(
      seriesId: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? 'Untitled',
      coverImagePath: json['cover_image_path']?.toString(),
      status: json['status']?.toString() ?? 'Planning',
      kind: json['kind']?.toString() ?? 'series',
      rating: json['rating'] is int
          ? json['rating']
          : int.tryParse(json['rating']?.toString() ?? ''),
      volumeCount: json['volume_count'] is int
          ? json['volume_count']
          : int.tryParse(json['volume_count']?.toString() ?? '') ?? 0,
      groupRole: json['group_role']?.toString().isNotEmpty == true
          ? json['group_role'].toString()
          : GroupRoles.mainStory,
      position: json['position'] is int
          ? json['position']
          : int.tryParse(json['position']?.toString() ?? '') ?? 0,
    );
  }
}

/// An umbrella group linking related series together.
class SeriesGroup {
  final int id;
  final int libraryId;
  final String name;
  final String groupType;
  final String? description;
  final int position;
  final List<SeriesGroupItem> items;

  const SeriesGroup({
    required this.id,
    required this.libraryId,
    required this.name,
    this.groupType = 'Series Group',
    this.description,
    this.position = 0,
    this.items = const [],
  });

  factory SeriesGroup.fromJson(
    Map<String, dynamic> json, {
    List<SeriesGroupItem> items = const [],
  }) {
    return SeriesGroup(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      libraryId: json['library_id'] is int
          ? json['library_id']
          : int.tryParse(json['library_id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      groupType: json['group_type']?.toString().isNotEmpty == true
          ? json['group_type'].toString()
          : 'Series Group',
      description: json['description']?.toString(),
      position: json['position'] is int
          ? json['position']
          : int.tryParse(json['position']?.toString() ?? '') ?? 0,
      items: items,
    );
  }
}

/// One row in the member-editor list while a group is being created/edited
/// (before it's saved back down to `series_group_items`).
class SeriesGroupDraftItem {
  final int seriesId;
  final String title;
  String groupRole;

  SeriesGroupDraftItem({
    required this.seriesId,
    required this.title,
    this.groupRole = GroupRoles.mainStory,
  });
}