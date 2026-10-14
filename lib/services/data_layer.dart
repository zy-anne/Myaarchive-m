import '../models/attachment.dart';
import '../models/character.dart';
import '../models/gallery_image.dart';
import '../models/glossary_term.dart';
import '../models/library.dart';
import '../models/metadata.dart';
import '../models/link_attachment.dart';
import '../models/reading_status_model.dart';
import '../models/relationship.dart';
import '../models/series.dart';
import '../models/series_group.dart';
import '../models/volume.dart';
import 'turso_client.dart';

/// Client-side data access.
///
/// Every call goes to the Worker's owner-checked `/api/rpc/<op>` endpoints.
/// The Worker takes the user id from the signed session token and proves
/// ownership of each row it touches, so no SQL is built or sent from here and
/// schema migrations are applied server-side (see `worker/src/schema.ts`).
class DataLayer {
  final TursoClient _api;

  DataLayer(this._api);

  /// Kept so existing callers keep working. Schema is now managed by the
  /// Worker (versioned migrations), so there is nothing to do on the client.
  Future<void> ensureSchema() async {}

  static const List<String> _tagColorPalette = [
    '#5DC8CD', '#9B7EDE', '#E58FB1', '#7FC9A0', '#B9BEC7', '#E8C15C', '#6FA8DC',
    '#4FBDB0', '#B0A15A', '#DD7A6E', '#E3A15C', '#8D9DE8', '#C98BC9', '#7FBF7F',
  ];

  static String colorForTagName(String name) {
    final key = name.trim().toLowerCase();
    int hash = 0;
    for (int i = 0; i < key.length; i++) {
      hash = (hash * 31 + key.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return _tagColorPalette[hash.abs() % _tagColorPalette.length];
  }

  // ─── helpers ────────────────────────────────────────────────────────

  // One-shot prefetch of libraries + statuses + settings (a single Worker
  // request instead of three). Each key is handed out once per sign-in;
  // later reads (pull-to-refresh, invalidate) go to the normal endpoints.
  Future<Map<String, dynamic>>? _boot;
  String _bootToken = '';
  DateTime _bootAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Map<String, dynamic>?> _takeBootstrapped(String key) async {
    final token = _api.sessionToken;
    if (token.isEmpty) return null;
    // Start one prefetch per sign-in; stale or already-taken data falls
    // through to the regular endpoint.
    if (_boot == null || _bootToken != token) {
      _bootToken = token;
      // An older Worker without the op (or any failure) just means each
      // caller falls back to its own request.
      _boot = _api
          .rpc('app.bootstrap')
          .catchError((_) => <String, dynamic>{})
          .then((d) {
        _bootAt = DateTime.now(); // freshness counts from arrival
        return d;
      });
    }
    final data = await _boot!;
    if (DateTime.now().difference(_bootAt) > const Duration(seconds: 20)) return null;
    final rows = data.remove(key);
    return rows is List ? {'rows': rows} : null;
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> res, [String key = 'rows']) =>
      ((res[key] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  int _id(Map<String, dynamic> res) {
    final v = res['id'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  // ─── Libraries ──────────────────────────────────────────────────────

  Future<List<Library>> librariesGetAll(String ownerId) async {
    final res = await _takeBootstrapped('libraries') ?? await _api.rpc('libraries.getAll');
    return _rows(res).map((r) => Library.fromJson(r)).toList();
  }

  Future<int> librariesCreate({
    required String ownerId,
    required String name,
    String icon = 'grid',
    String? iconImage,
  }) async {
    final res = await _api.rpc('libraries.create', {
      'name': name,
      'icon': icon,
      'iconImage': iconImage,
    });
    return _id(res);
  }

  Future<void> librariesUpdate(Library lib) async {
    await _api.rpc('libraries.update', {
      'id': lib.id,
      'name': lib.name,
      'icon': lib.icon,
      'iconImage': lib.iconImage,
    });
  }

  Future<void> librariesDelete(int id) async {
    await _api.rpc('libraries.delete', {'id': id});
  }

  /// Persists a new drag-to-reorder order. [orderedIds] is the full list of
  /// library ids in display order.
  Future<void> librariesReorder(List<int> orderedIds) async {
    if (orderedIds.isEmpty) return;
    await _api.rpc('libraries.reorder', {'ids': orderedIds});
  }

  // ─── Series ─────────────────────────────────────────────────────────

  Map<String, dynamic> _seriesPayload(Series s) => {
        'title': s.title,
        'author': s.author,
        'status': s.status,
        'synopsis': s.synopsis,
        'library_id': s.libraryId,
        'kind': s.kind,
        'overall_thoughts': s.overallThoughts,
        'chapter_thoughts': s.chapterThoughts,
        'cover_image_path': s.coverImagePath,
        'book_type': s.bookType,
        'rating': s.rating,
        'original_language': s.originalLanguage,
        'country_of_origin': s.countryOfOrigin,
        'language_read': s.languageRead,
        'artist': s.artist,
        'year_published': s.yearPublished,
        'date_started': s.dateStarted,
        'date_finished': s.dateFinished,
        'status_country_of_origin': s.statusCountryOfOrigin,
        'licensed_english': s.licensedEnglish,
        'completely_translated': s.completelyTranslated,
        'original_publisher': s.originalPublisher,
        'english_publisher': s.englishPublisher,
        'is_nsfw': s.isNsfw ? 1 : 0,
        'standalone_chapter_count': s.standaloneChapterCount,
        'fandom': s.fandom,
      };

  /// Fetches titles for the signed-in user's libraries, applying every filter
  /// the Library screen's Sort & Filters sheet can set. Genre and tag filters
  /// have independent Any/All controls ([matchAllGenres], [matchAllTags]).
  Future<List<Series>> seriesGetAll(
    String ownerId, {
    int? libraryId,
    String? status,
    String? search,
    List<String> genres = const [],
    List<String> tags = const [],
    bool matchAllGenres = false,
    bool matchAllTags = false,
    int? minRating,
    int? yearFrom,
    int? yearTo,
    String? bookType,
    String? languageRead,
    String? originalLanguage,
    String? countryOfOrigin,
    String? translationStatus,
    String? author,
    String? artist,
    String? publisher,
    String sortBy = 'title',
    bool sortAsc = true,
    bool includeNsfw = true,
  }) async {
    final res = await _api.rpc('series.getAll', {
      'libraryId': libraryId,
      'status': status,
      'search': search,
      'genres': genres,
      'tags': tags,
      'matchAllGenres': matchAllGenres,
      'matchAllTags': matchAllTags,
      'minRating': minRating,
      'yearFrom': yearFrom,
      'yearTo': yearTo,
      'bookType': bookType,
      'languageRead': languageRead,
      'originalLanguage': originalLanguage,
      'countryOfOrigin': countryOfOrigin,
      'translationStatus': translationStatus,
      'author': author,
      'artist': artist,
      'publisher': publisher,
      'sortBy': sortBy,
      'sortAsc': sortAsc,
      'includeNsfw': includeNsfw,
    });
    return _rows(res).map((r) => Series.fromJson(r)).toList();
  }

  Future<Series?> seriesGetById(int id) async {
    final res = await _api.rpc('series.getById', {'id': id});
    final row = res['row'];
    if (row == null) return null;
    return Series.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<int> seriesCreate(
    String ownerId,
    Series series, {
    List<String> tagNames = const [],
    List<String> genreNames = const [],
    List<String> warningNames = const [],
  }) async {
    final res = await _api.rpc('series.create', {
      'series': _seriesPayload(series),
      'tagNames': tagNames,
      'genreNames': genreNames,
      'warningNames': warningNames,
    });
    return _id(res);
  }

  Future<void> seriesUpdate(
    String ownerId,
    Series series, {
    List<String> tagNames = const [],
    List<String> genreNames = const [],
    List<String> warningNames = const [],
  }) async {
    await _api.rpc('series.update', {
      'id': series.id,
      'series': _seriesPayload(series),
      'tagNames': tagNames,
      'genreNames': genreNames,
      'warningNames': warningNames,
    });
  }

  /// Deletes a title and everything attached to it in one transaction, then
  /// removes any R2 objects nothing else references.
  Future<void> seriesDelete(int id) async {
    await _api.rpc('series.delete', {'id': id});
  }

  /// Moves a title to another library in place; children move with it.
  Future<void> seriesTransferTo(int seriesId, int targetLibraryId) async {
    await _api.rpc('series.transfer', {
      'id': seriesId,
      'targetLibraryId': targetLibraryId,
    });
  }

  /// Duplicates a title into another library. Copied images share their R2
  /// objects with the original; the Worker only deletes an object once no row
  /// references it. Returns the new series id.
  Future<int> seriesCopyTo(
    int seriesId,
    int targetLibraryId, {
    bool includeVolumes = true,
    bool includeCharacters = true,
    bool includeGallery = true,
    bool includeAttachments = true,
  }) async {
    final res = await _api.rpc('series.copy', {
      'id': seriesId,
      'targetLibraryId': targetLibraryId,
      'includeVolumes': includeVolumes,
      'includeCharacters': includeCharacters,
      'includeGallery': includeGallery,
      'includeAttachments': includeAttachments,
    });
    return _id(res);
  }

  // ─── Series Groups ──────────────────────────────────────────────────

  Future<List<SeriesGroup>> seriesGroupsGetAll(int libraryId) async {
    final res = await _api.rpc('groups.getAll', {'libraryId': libraryId});
    final byGroup = <int, List<SeriesGroupItem>>{};
    for (final r in _rows(res, 'items')) {
      final gid = r['group_id'] is int
          ? r['group_id'] as int
          : int.tryParse(r['group_id'].toString()) ?? 0;
      byGroup.putIfAbsent(gid, () => []).add(SeriesGroupItem.fromJson(r));
    }
    return _rows(res, 'groups').map((g) {
      final gid =
          g['id'] is int ? g['id'] as int : int.tryParse(g['id'].toString()) ?? 0;
      return SeriesGroup.fromJson(g, items: byGroup[gid] ?? const []);
    }).toList();
  }

  List<Map<String, dynamic>> _groupItems(List<MapEntry<int, String>> items) =>
      items.map((e) => {'seriesId': e.key, 'role': e.value}).toList();

  /// [items] is (seriesId, groupRole) pairs in display order.
  Future<int> seriesGroupsCreate({
    required int libraryId,
    required String name,
    String groupType = 'Series Group',
    String? description,
    List<MapEntry<int, String>> items = const [],
  }) async {
    final res = await _api.rpc('groups.create', {
      'libraryId': libraryId,
      'name': name,
      'groupType': groupType,
      'description': description,
      'items': _groupItems(items),
    });
    return _id(res);
  }

  Future<void> seriesGroupsUpdate(
    int id, {
    required String name,
    String groupType = 'Series Group',
    String? description,
    List<MapEntry<int, String>> items = const [],
  }) async {
    await _api.rpc('groups.update', {
      'id': id,
      'name': name,
      'groupType': groupType,
      'description': description,
      'items': _groupItems(items),
    });
  }

  Future<void> seriesGroupsDelete(int id) async {
    await _api.rpc('groups.delete', {'id': id});
  }

  // ─── Child records (volumes, characters, gallery, links, files, glossary)

  Future<List<Map<String, dynamic>>> _childList(String table, int seriesId) async =>
      _rows(await _api.rpc('child.list', {'table': table, 'seriesId': seriesId}));

  Future<int> _childCreate(String table, int seriesId, Map<String, dynamic> row) async =>
      _id(await _api.rpc('child.create', {
        'table': table,
        'seriesId': seriesId,
        'row': row,
      }));

  Future<void> _childUpdate(String table, int id, Map<String, dynamic> row) async {
    await _api.rpc('child.update', {'table': table, 'id': id, 'row': row});
  }

  Future<void> _childDelete(String table, int id) async {
    await _api.rpc('child.delete', {'table': table, 'id': id});
  }

  // Volumes

  Map<String, dynamic> _volumeRow(Volume v) => {
        'volume_number': v.volumeNumber,
        'title': v.title,
        'chapter_range': v.chapterRange,
        'chapter_count': v.chapterCount,
        'thoughts': v.thoughts,
        'chapter_notes': v.chapterNotes,
        'cover_image_path': v.coverImagePath,
        'date_read': v.dateRead,
        'published_date': v.publishedDate,
      };

  Future<List<Volume>> volumesGetBySeries(int seriesId) async =>
      (await _childList('volumes', seriesId)).map((r) => Volume.fromJson(r)).toList();

  Future<int> volumesCreate(Volume volume) =>
      _childCreate('volumes', volume.seriesId, _volumeRow(volume));

  Future<void> volumesUpdate(Volume volume) =>
      _childUpdate('volumes', volume.id, _volumeRow(volume));

  Future<void> volumesDelete(int id) => _childDelete('volumes', id);

  // Characters

  Map<String, dynamic> _characterRow(Character c) => {
        'name': c.name,
        'role': c.role,
        'volume_appearances': c.volumeAppearances,
        'notes': c.notes,
        'profile_image_path': c.profileImagePath,
        'status_role': c.statusRole,
        'overall_vibes': c.overallVibes,
        'appears_vs_reality': c.appearsVsReality,
        'appears_text': c.appearsText,
        'reality_text': c.realityText,
        'personality': c.personality,
        'age': c.age,
        'life_status': c.lifeStatus,
      };

  Future<List<Character>> charactersGetBySeries(int seriesId) async =>
      (await _childList('characters', seriesId)).map((r) => Character.fromJson(r)).toList();

  Future<int> charactersCreate(Character c) =>
      _childCreate('characters', c.seriesId, _characterRow(c));

  Future<void> charactersUpdate(Character c) =>
      _childUpdate('characters', c.id, _characterRow(c));

  /// Also removes the character's relationships (server-side, one transaction).
  Future<void> charactersDelete(int id) => _childDelete('characters', id);

  // Relationships

  Future<List<Relationship>> relationshipsGetBySeries(int seriesId) async {
    final res = await _api.rpc('relationships.list', {'seriesId': seriesId});
    return _rows(res).map((r) => Relationship.fromJson(r)).toList();
  }

  Map<String, dynamic> _relPayload(Relationship rel) => {
        'fromCharacterId': rel.fromCharacterId,
        'toCharacterId': rel.toCharacterId,
        'type': rel.type,
        'label': rel.label,
        'isBidirectional': rel.isBidirectional,
        'notes': rel.notes,
      };

  Future<int> relationshipsCreate(Relationship rel) async =>
      _id(await _api.rpc('relationships.create', _relPayload(rel)));

  Future<void> relationshipsUpdate(Relationship rel) async {
    await _api.rpc('relationships.update', {'id': rel.id, ..._relPayload(rel)});
  }

  Future<void> relationshipsDelete(int id) async {
    await _api.rpc('relationships.delete', {'id': id});
  }

  // Gallery

  Future<List<GalleryImage>> galleryGetBySeries(int seriesId) async =>
      (await _childList('gallery_images', seriesId)).map((r) => GalleryImage.fromJson(r)).toList();

  Future<int> galleryAdd(GalleryImage img) => _childCreate('gallery_images', img.seriesId, {
        'image_path': img.imagePath,
        'caption': img.caption,
        'position': img.position,
      });

  Future<void> galleryDelete(int id) => _childDelete('gallery_images', id);

  // Links

  Future<List<LinkAttachment>> linksGetBySeries(int seriesId) async =>
      (await _childList('link_attachments', seriesId)).map((r) => LinkAttachment.fromJson(r)).toList();

  Future<int> linksAdd(LinkAttachment link) => _childCreate(
      'link_attachments', link.seriesId, {'url': link.url, 'label': link.label});

  Future<void> linksUpdate(LinkAttachment link) =>
      _childUpdate('link_attachments', link.id, {'url': link.url, 'label': link.label});

  Future<void> linksDelete(int id) => _childDelete('link_attachments', id);

  // Attachments

  Future<List<Attachment>> attachmentsGetBySeries(int seriesId) async =>
      (await _childList('attachments', seriesId)).map((r) => Attachment.fromJson(r)).toList();

  Future<int> attachmentsAdd(Attachment a) => _childCreate('attachments', a.seriesId, {
        'file_path': a.filePath,
        'file_name': a.fileName,
        'file_size': a.fileSize,
      });

  Future<void> attachmentsDelete(int id) => _childDelete('attachments', id);

  // Glossary

  Future<List<GlossaryTerm>> glossaryGetBySeries(int seriesId) async =>
      (await _childList('glossary_terms', seriesId)).map((r) => GlossaryTerm.fromJson(r)).toList();

  Future<int> glossaryAdd(GlossaryTerm t) => _childCreate(
      'glossary_terms', t.seriesId, {'term': t.term, 'definition': t.definition});

  Future<void> glossaryUpdate(GlossaryTerm t) =>
      _childUpdate('glossary_terms', t.id, {'term': t.term, 'definition': t.definition});

  Future<void> glossaryDelete(int id) => _childDelete('glossary_terms', id);

  // ─── Metadata lists ─────────────────────────────────────────────────

  Future<List<Tag>> tagsGetAll(String ownerId) async =>
      _rows(await _api.rpc('tags.getAll')).map((r) => Tag.fromJson(r)).toList();

  Future<void> tagsUpdate(Tag tag) async {
    await _api.rpc('tags.update', {'id': tag.id, 'name': tag.name, 'color': tag.color});
  }

  /// Deletes a tag and removes it from every title using it.
  Future<void> tagsDelete(int id) async {
    await _api.rpc('tags.delete', {'id': id});
  }

  Future<List<Genre>> genresGetAll() async =>
      _rows(await _api.rpc('genres.getAll')).map((r) => Genre.fromJson(r)).toList();

  Future<List<ContentWarning>> contentWarningsGetAll(String ownerId) async =>
      _rows(await _api.rpc('warnings.getAll')).map((r) => ContentWarning.fromJson(r)).toList();

  // ─── Reading statuses ───────────────────────────────────────────────

  /// Per-user statuses; the Worker seeds the five defaults on first read.
  Future<List<ReadingStatusItem>> statusesGetAll(String ownerId) async =>
      _rows(await _takeBootstrapped('statuses') ?? await _api.rpc('statuses.getAll')).map((r) => ReadingStatusItem.fromJson(r)).toList();

  Future<int> statusesCreate(String ownerId, String name, String color) async =>
      _id(await _api.rpc('statuses.create', {'name': name, 'color': color}));

  /// Renames/recolors a status; a rename cascades onto the caller's own
  /// titles only. [previousName] is accepted for compatibility — the Worker
  /// reads the stored name itself.
  Future<void> statusesUpdate(
    ReadingStatusItem status, {
    String? previousName,
  }) async {
    await _api.rpc('statuses.update', {
      'id': status.id,
      'name': status.name,
      'color': status.color,
    });
  }

  Future<void> statusesDelete(
    int id,
    String name,
    String ownerId, {
    String fallbackName = 'Planning',
  }) async {
    await _api.rpc('statuses.delete', {'id': id, 'fallbackName': fallbackName});
  }

  // ─── App settings ───────────────────────────────────────────────────

  Future<Map<String, String>> settingsGetAll(String ownerId) async {
    final res = await _takeBootstrapped('settings') ?? await _api.rpc('settings.getAll');
    final map = <String, String>{};
    for (final r in _rows(res)) {
      if (r['key'] != null && r['value'] != null) {
        map[r['key'].toString()] = r['value'].toString();
      }
    }
    return map;
  }

  Future<void> settingsSet(String ownerId, String key, String value) async {
    await _api.rpc('settings.set', {'key': key, 'value': value});
  }

  // ─── Backup ─────────────────────────────────────────────────────────

  /// Everything the signed-in user owns, as a JSON-ready map.
  Future<Map<String, dynamic>> exportBackup() async {
    final res = await _api.rpc('data.export', null, const Duration(minutes: 2));
    final backup = res['backup'];
    if (backup is! Map) throw TursoException('Export returned no data');
    return Map<String, dynamic>.from(backup);
  }

  /// Additive restore; returns {libraries, series, skipped}.
  Future<Map<String, dynamic>> importBackup(Map<String, dynamic> data) =>
      _api.rpc('data.import', {'data': data}, const Duration(minutes: 5));
}
