import '../models/attachment.dart';
import '../models/character.dart';
import '../models/gallery_image.dart';
import '../models/glossary_term.dart';
import '../models/library.dart';
import '../models/metadata.dart';
import '../models/link_attachment.dart';
import '../models/relationship.dart';
import '../models/series.dart';
import '../models/volume.dart';
import 'turso_client.dart';

/// Data layer ported directly from `reading-library/data-layer/index.js`.
///
/// Communicates with Turso over HTTP (Hrana v2 pipeline) for all queries,
/// mutations, transactions, and schema management.
class DataLayer {
  final TursoClient _turso;

  DataLayer(this._turso);

  // ─── Tag color palette (deterministic matching index.js) ───────────
  static const List<String> _tagColorPalette = [
    '#5DC8CD', // cyan
    '#9B7EDE', // purple
    '#E58FB1', // pink
    '#7FC9A0', // green
    '#B9BEC7', // gray
    '#E8C15C', // gold
    '#6FA8DC', // blue
    '#4FBDB0', // teal
    '#B0A15A', // olive
    '#DD7A6E', // rust
    '#E3A15C', // orange
    '#8D9DE8', // periwinkle
    '#C98BC9', // orchid
    '#7FBF7F', // leaf green
  ];

  static String colorForTagName(String name) {
    final key = name.trim().toLowerCase();
    int hash = 0;
    for (int i = 0; i < key.length; i++) {
      hash = (hash * 31 + key.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return _tagColorPalette[hash.abs() % _tagColorPalette.length];
  }

  // ─── Schema Initialization ─────────────────────────────────────────

  Future<void> ensureSchema() async {
    await _turso.batch([
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS libraries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          owner_id TEXT NOT NULL,
          name TEXT NOT NULL,
          icon TEXT DEFAULT 'grid',
          icon_image TEXT,
          position INTEGER NOT NULL DEFAULT 0
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS app_settings (
          owner_id TEXT NOT NULL,
          key TEXT NOT NULL,
          value TEXT,
          UNIQUE(owner_id, key)
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS genres (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL COLLATE NOCASE,
          color TEXT DEFAULT '#b2bec3'
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          owner_id TEXT NOT NULL,
          name TEXT NOT NULL COLLATE NOCASE,
          color TEXT DEFAULT '#4a90e2',
          UNIQUE(owner_id, name)
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS series (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          author TEXT,
          status TEXT DEFAULT 'Planning',
          synopsis TEXT,
          library_id INTEGER NOT NULL,
          kind TEXT DEFAULT 'series',
          overall_thoughts TEXT,
          chapter_thoughts TEXT,
          cover_image_path TEXT
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS volumes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          series_id INTEGER NOT NULL,
          volume_number INTEGER NOT NULL,
          title TEXT,
          chapter_range TEXT,
          chapter_count INTEGER,
          thoughts TEXT,
          chapter_notes TEXT,
          cover_image_path TEXT,
          date_read TEXT
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS characters (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          series_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          role TEXT DEFAULT 'Side',
          volume_appearances TEXT,
          notes TEXT,
          profile_image_path TEXT
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS relationships (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          from_character_id INTEGER NOT NULL,
          to_character_id INTEGER NOT NULL,
          type TEXT DEFAULT 'Friend',
          label TEXT,
          is_bidirectional INTEGER DEFAULT 1,
          notes TEXT
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS series_tags (
          series_id INTEGER NOT NULL,
          tag_id INTEGER NOT NULL,
          UNIQUE(series_id, tag_id)
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS series_genres (
          series_id INTEGER NOT NULL,
          genre_id INTEGER NOT NULL,
          UNIQUE(series_id, genre_id)
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS content_warnings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          owner_id TEXT NOT NULL,
          name TEXT NOT NULL COLLATE NOCASE,
          UNIQUE(owner_id, name)
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS series_content_warnings (
          series_id INTEGER NOT NULL,
          warning_id INTEGER NOT NULL,
          UNIQUE(series_id, warning_id)
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS gallery_images (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          series_id INTEGER NOT NULL,
          image_path TEXT NOT NULL,
          caption TEXT,
          position INTEGER NOT NULL DEFAULT 0
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS link_attachments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          series_id INTEGER NOT NULL,
          url TEXT NOT NULL,
          label TEXT,
          created_at TEXT DEFAULT (datetime('now'))
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS attachments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          series_id INTEGER NOT NULL,
          file_path TEXT NOT NULL,
          file_name TEXT NOT NULL,
          file_size INTEGER,
          created_at TEXT DEFAULT (datetime('now'))
        )
      ''', []),
      const MapEntry('''
        CREATE TABLE IF NOT EXISTS glossary_terms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          series_id INTEGER NOT NULL,
          term TEXT NOT NULL,
          definition TEXT
        )
      ''', []),
    ]);

    // Ensure extra migration columns exist
    await _ensureExtraColumns();
  }

  Future<void> _ensureExtraColumns() async {
    try {
      final infoSeries = await _turso.execute('PRAGMA table_info(series)');
      final existingSeriesCols =
          infoSeries.rows.map((r) => r['name']?.toString()).toSet();

      final seriesExtraFields = [
        ['book_type', 'TEXT'],
        ['rating', 'INTEGER'],
        ['original_language', 'TEXT'],
        ['country_of_origin', 'TEXT'],
        ['language_read', "TEXT DEFAULT 'English'"],
        ['artist', 'TEXT'],
        ['year_published', 'TEXT'],
        ['date_started', 'TEXT'],
        ['date_finished', 'TEXT'],
        ['status_country_of_origin', 'TEXT'],
        ['licensed_english', 'TEXT'],
        ['completely_translated', 'TEXT'],
        ['original_publisher', 'TEXT'],
        ['english_publisher', 'TEXT'],
        ['is_nsfw', 'INTEGER NOT NULL DEFAULT 0'],
        ['standalone_chapter_count', 'INTEGER'],
        ['fandom', 'TEXT'],
      ];

      for (final f in seriesExtraFields) {
        if (!existingSeriesCols.contains(f[0])) {
          await _turso.execute('ALTER TABLE series ADD COLUMN ${f[0]} ${f[1]}');
        }
      }

      final infoVolumes = await _turso.execute('PRAGMA table_info(volumes)');
      final existingVolCols =
          infoVolumes.rows.map((r) => r['name']?.toString()).toSet();
      if (!existingVolCols.contains('published_date')) {
        await _turso.execute('ALTER TABLE volumes ADD COLUMN published_date TEXT');
      }

      final infoChars = await _turso.execute('PRAGMA table_info(characters)');
      final existingCharCols =
          infoChars.rows.map((r) => r['name']?.toString()).toSet();
      final charFields = [
        ['status_role', 'TEXT'],
        ['overall_vibes', 'TEXT'],
        ['appears_vs_reality', 'TEXT'],
        ['appears_text', 'TEXT'],
        ['reality_text', 'TEXT'],
        ['personality', 'TEXT'],
        ['age', 'TEXT'],
        ['life_status', 'TEXT'],
      ];
      for (final f in charFields) {
        if (!existingCharCols.contains(f[0])) {
          await _turso.execute('ALTER TABLE characters ADD COLUMN ${f[0]} ${f[1]}');
        }
      }
    } catch (_) {}
  }

  // ─── Libraries ──────────────────────────────────────────────────────

  Future<List<Library>> librariesGetAll(String ownerId) async {
    final result = await _turso.execute('''
      SELECT l.*, COUNT(s.id) as series_count
      FROM libraries l
      LEFT JOIN series s ON s.library_id = l.id
      WHERE l.owner_id = ?
      GROUP BY l.id
      ORDER BY l.position, l.id
    ''', [ownerId]);

    final list = result.rows.map((r) => Library.fromJson(r)).toList();

    // Default library if empty
    if (list.isEmpty) {
      final defaultId = await librariesCreate(
        ownerId: ownerId,
        name: 'Default Library',
        icon: 'book',
      );
      return [
        Library(
          id: defaultId,
          ownerId: ownerId,
          name: 'Default Library',
          icon: 'book',
        )
      ];
    }
    return list;
  }

  Future<int> librariesCreate({
    required String ownerId,
    required String name,
    String icon = 'grid',
    String? iconImage,
  }) async {
    final maxRes = await _turso.execute(
      'SELECT MAX(position) as maxPos FROM libraries WHERE owner_id = ?',
      [ownerId],
    );
    int pos = 0;
    if (maxRes.rows.isNotEmpty && maxRes.rows.first['maxPos'] != null) {
      pos = (maxRes.rows.first['maxPos'] as int) + 1;
    }

    final res = await _turso.execute('''
      INSERT INTO libraries (owner_id, name, icon, icon_image, position)
      VALUES (?, ?, ?, ?, ?)
    ''', [ownerId, name, icon, iconImage, pos]);

    return res.lastInsertRowid ?? 0;
  }

  Future<void> librariesUpdate(Library lib) async {
    await _turso.execute('''
      UPDATE libraries SET name = ?, icon = ?, icon_image = ? WHERE id = ?
    ''', [lib.name, lib.icon, lib.iconImage, lib.id]);
  }

  Future<void> librariesDelete(int id) async {
    await _turso.execute('DELETE FROM libraries WHERE id = ?', [id]);
  }

  // ─── Series Query & Detail ──────────────────────────────────────────

  static const String _seriesSelect = '''
    SELECT s.*,
      (SELECT GROUP_CONCAT(t.id || '::' || t.name || '::' || t.color, '||')
         FROM series_tags st JOIN tags t ON st.tag_id = t.id
         WHERE st.series_id = s.id) as tag_data,
      (SELECT GROUP_CONCAT(g.id || '::' || g.name || '::' || g.color, '||')
         FROM series_genres sg JOIN genres g ON sg.genre_id = g.id
         WHERE sg.series_id = s.id) as genre_data,
      (SELECT GROUP_CONCAT(cw.id || '::' || cw.name, '||')
         FROM series_content_warnings scw JOIN content_warnings cw ON scw.warning_id = cw.id
         WHERE scw.series_id = s.id) as warning_data,
      (SELECT COUNT(*) FROM volumes v WHERE v.series_id = s.id) as volume_count,
      (SELECT COUNT(*) FROM characters c WHERE c.series_id = s.id) as character_count
    FROM series s
  ''';

  Future<List<Series>> seriesGetAll(
    String ownerId, {
    int? libraryId,
    String? status,
    String? search,
    List<String>? tags,
    List<String>? genres,
    String sortBy = 'title',
    bool sortAsc = true,
  }) async {
    final whereClauses = <String>[
      's.library_id IN (SELECT id FROM libraries WHERE owner_id = ?)'
    ];
    final args = <dynamic>[ownerId];

    if (libraryId != null && libraryId > 0) {
      whereClauses.add('s.library_id = ?');
      args.add(libraryId);
    }

    if (status != null && status != 'All' && status.isNotEmpty) {
      whereClauses.add('s.status = ?');
      args.add(status);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(s.title LIKE ? OR s.author LIKE ? OR s.fandom LIKE ?)');
      final term = '%${search.trim()}%';
      args.addAll([term, term, term]);
    }

    final where = 'WHERE ${whereClauses.join(' AND ')}';
    String order = 'ORDER BY s.title COLLATE NOCASE ASC';
    if (sortBy == 'rating') {
      order = 'ORDER BY s.rating ${sortAsc ? 'ASC' : 'DESC'}, s.title ASC';
    } else if (sortBy == 'id') {
      order = 'ORDER BY s.id ${sortAsc ? 'ASC' : 'DESC'}';
    } else {
      order = 'ORDER BY s.title COLLATE NOCASE ${sortAsc ? 'ASC' : 'DESC'}';
    }

    final sql = '$_seriesSelect $where $order';
    final result = await _turso.execute(sql, args);
    return result.rows.map((r) => Series.fromJson(r)).toList();
  }

  Future<Series?> seriesGetById(int id) async {
    final result = await _turso.execute(
      '$_seriesSelect WHERE s.id = ?',
      [id],
    );
    if (result.rows.isEmpty) return null;
    return Series.fromJson(result.rows.first);
  }

  // ─── Series Create & Update ─────────────────────────────────────────

  Future<int> seriesCreate(
    String ownerId,
    Series series, {
    List<String> tagNames = const [],
    List<String> genreNames = const [],
    List<String> warningNames = const [],
  }) async {
    final sql = '''
      INSERT INTO series (
        title, author, status, synopsis, library_id, kind, overall_thoughts,
        chapter_thoughts, cover_image_path, book_type, rating, original_language,
        country_of_origin, language_read, artist, year_published, date_started,
        date_finished, status_country_of_origin, licensed_english,
        completely_translated, original_publisher, english_publisher,
        is_nsfw, standalone_chapter_count, fandom
      ) VALUES (
        ?, ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?,
        ?, ?, ?,
        ?, ?, ?
      )
    ''';

    final args = [
      series.title,
      series.author,
      series.status,
      series.synopsis,
      series.libraryId,
      series.kind,
      series.overallThoughts,
      series.chapterThoughts,
      series.coverImagePath,
      series.bookType,
      series.rating,
      series.originalLanguage,
      series.countryOfOrigin,
      series.languageRead,
      series.artist,
      series.yearPublished,
      series.dateStarted,
      series.dateFinished,
      series.statusCountryOfOrigin,
      series.licensedEnglish,
      series.completelyTranslated,
      series.originalPublisher,
      series.englishPublisher,
      series.isNsfw ? 1 : 0,
      series.standaloneChapterCount,
      series.fandom,
    ];

    final res = await _turso.execute(sql, args);
    final seriesId = res.lastInsertRowid ?? 0;

    // Link tags, genres, content warnings
    if (seriesId > 0) {
      await _syncTags(ownerId, seriesId, tagNames);
      await _syncGenres(seriesId, genreNames);
      await _syncWarnings(ownerId, seriesId, warningNames);
    }

    return seriesId;
  }

  Future<void> seriesUpdate(
    String ownerId,
    Series series, {
    List<String> tagNames = const [],
    List<String> genreNames = const [],
    List<String> warningNames = const [],
  }) async {
    final sql = '''
      UPDATE series SET
        title = ?, author = ?, status = ?, synopsis = ?, library_id = ?,
        kind = ?, overall_thoughts = ?, chapter_thoughts = ?,
        cover_image_path = ?, book_type = ?, rating = ?, original_language = ?,
        country_of_origin = ?, language_read = ?, artist = ?, year_published = ?,
        date_started = ?, date_finished = ?, status_country_of_origin = ?,
        licensed_english = ?, completely_translated = ?, original_publisher = ?,
        english_publisher = ?, is_nsfw = ?, standalone_chapter_count = ?,
        fandom = ?
      WHERE id = ?
    ''';

    final args = [
      series.title,
      series.author,
      series.status,
      series.synopsis,
      series.libraryId,
      series.kind,
      series.overallThoughts,
      series.chapterThoughts,
      series.coverImagePath,
      series.bookType,
      series.rating,
      series.originalLanguage,
      series.countryOfOrigin,
      series.languageRead,
      series.artist,
      series.yearPublished,
      series.dateStarted,
      series.dateFinished,
      series.statusCountryOfOrigin,
      series.licensedEnglish,
      series.completelyTranslated,
      series.originalPublisher,
      series.englishPublisher,
      series.isNsfw ? 1 : 0,
      series.standaloneChapterCount,
      series.fandom,
      series.id,
    ];

    await _turso.execute(sql, args);

    await _syncTags(ownerId, series.id, tagNames);
    await _syncGenres(series.id, genreNames);
    await _syncWarnings(ownerId, series.id, warningNames);
  }

  Future<void> seriesDelete(int id) async {
    await _turso.batch([
      MapEntry('DELETE FROM series_tags WHERE series_id = ?', [id]),
      MapEntry('DELETE FROM series_genres WHERE series_id = ?', [id]),
      MapEntry('DELETE FROM series_content_warnings WHERE series_id = ?', [id]),
      MapEntry('DELETE FROM volumes WHERE series_id = ?', [id]),
      MapEntry('DELETE FROM characters WHERE series_id = ?', [id]),
      MapEntry('DELETE FROM gallery_images WHERE series_id = ?', [id]),
      MapEntry('DELETE FROM link_attachments WHERE series_id = ?', [id]),
      MapEntry('DELETE FROM series WHERE id = ?', [id]),
    ]);
  }

  Future<void> _syncTags(String ownerId, int seriesId, List<String> tagNames) async {
    await _turso.execute('DELETE FROM series_tags WHERE series_id = ?', [seriesId]);
    for (final name in tagNames) {
      final t = name.trim();
      if (t.isEmpty) continue;
      final color = colorForTagName(t);
      await _turso.execute(
        'INSERT OR IGNORE INTO tags (owner_id, name, color) VALUES (?, ?, ?)',
        [ownerId, t, color],
      );
      final tagRes = await _turso.execute(
        'SELECT id FROM tags WHERE owner_id = ? AND name = ?',
        [ownerId, t],
      );
      if (tagRes.rows.isNotEmpty) {
        final tagId = tagRes.rows.first['id'];
        await _turso.execute(
          'INSERT OR IGNORE INTO series_tags (series_id, tag_id) VALUES (?, ?)',
          [seriesId, tagId],
        );
      }
    }
  }

  Future<void> _syncGenres(int seriesId, List<String> genreNames) async {
    await _turso.execute('DELETE FROM series_genres WHERE series_id = ?', [seriesId]);
    for (final name in genreNames) {
      final g = name.trim();
      if (g.isEmpty) continue;
      await _turso.execute(
        'INSERT OR IGNORE INTO genres (name) VALUES (?)',
        [g],
      );
      final genreRes = await _turso.execute(
        'SELECT id FROM genres WHERE name = ?',
        [g],
      );
      if (genreRes.rows.isNotEmpty) {
        final genreId = genreRes.rows.first['id'];
        await _turso.execute(
          'INSERT OR IGNORE INTO series_genres (series_id, genre_id) VALUES (?, ?)',
          [seriesId, genreId],
        );
      }
    }
  }

  Future<void> _syncWarnings(String ownerId, int seriesId, List<String> warningNames) async {
    await _turso.execute(
      'DELETE FROM series_content_warnings WHERE series_id = ?',
      [seriesId],
    );
    for (final name in warningNames) {
      final w = name.trim();
      if (w.isEmpty) continue;
      await _turso.execute(
        'INSERT OR IGNORE INTO content_warnings (owner_id, name) VALUES (?, ?)',
        [ownerId, w],
      );
      final warnRes = await _turso.execute(
        'SELECT id FROM content_warnings WHERE owner_id = ? AND name = ?',
        [ownerId, w],
      );
      if (warnRes.rows.isNotEmpty) {
        final warnId = warnRes.rows.first['id'];
        await _turso.execute(
          'INSERT OR IGNORE INTO series_content_warnings (series_id, warning_id) VALUES (?, ?)',
          [seriesId, warnId],
        );
      }
    }
  }

  // ─── Volumes ─────────────────────────────────────────────────────────

  Future<List<Volume>> volumesGetBySeries(int seriesId) async {
    final res = await _turso.execute(
      'SELECT * FROM volumes WHERE series_id = ? ORDER BY volume_number ASC',
      [seriesId],
    );
    return res.rows.map((r) => Volume.fromJson(r)).toList();
  }

  Future<int> volumesCreate(Volume volume) async {
    final sql = '''
      INSERT INTO volumes (
        series_id, volume_number, title, chapter_range, chapter_count,
        thoughts, chapter_notes, cover_image_path, date_read, published_date
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''';
    final args = [
      volume.seriesId,
      volume.volumeNumber,
      volume.title,
      volume.chapterRange,
      volume.chapterCount,
      volume.thoughts,
      volume.chapterNotes,
      volume.coverImagePath,
      volume.dateRead,
      volume.publishedDate,
    ];
    final res = await _turso.execute(sql, args);
    return res.lastInsertRowid ?? 0;
  }

  Future<void> volumesUpdate(Volume volume) async {
    final sql = '''
      UPDATE volumes SET
        volume_number = ?, title = ?, chapter_range = ?, chapter_count = ?,
        thoughts = ?, chapter_notes = ?, cover_image_path = ?,
        date_read = ?, published_date = ?
      WHERE id = ?
    ''';
    final args = [
      volume.volumeNumber,
      volume.title,
      volume.chapterRange,
      volume.chapterCount,
      volume.thoughts,
      volume.chapterNotes,
      volume.coverImagePath,
      volume.dateRead,
      volume.publishedDate,
      volume.id,
    ];
    await _turso.execute(sql, args);
  }

  Future<void> volumesDelete(int id) async {
    await _turso.execute('DELETE FROM volumes WHERE id = ?', [id]);
  }

  // ─── Characters ─────────────────────────────────────────────────────

  Future<List<Character>> charactersGetBySeries(int seriesId) async {
    final res = await _turso.execute(
      'SELECT * FROM characters WHERE series_id = ? ORDER BY name COLLATE NOCASE',
      [seriesId],
    );
    return res.rows.map((r) => Character.fromJson(r)).toList();
  }

  Future<int> charactersCreate(Character c) async {
    final sql = '''
      INSERT INTO characters (
        series_id, name, role, volume_appearances, notes, profile_image_path,
        status_role, overall_vibes, appears_vs_reality, appears_text,
        reality_text, personality, age, life_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''';
    final args = [
      c.seriesId,
      c.name,
      c.role,
      c.volumeAppearances,
      c.notes,
      c.profileImagePath,
      c.statusRole,
      c.overallVibes,
      c.appearsVsReality,
      c.appearsText,
      c.realityText,
      c.personality,
      c.age,
      c.lifeStatus,
    ];
    final res = await _turso.execute(sql, args);
    return res.lastInsertRowid ?? 0;
  }

  Future<void> charactersUpdate(Character c) async {
    final sql = '''
      UPDATE characters SET
        name = ?, role = ?, volume_appearances = ?, notes = ?, profile_image_path = ?,
        status_role = ?, overall_vibes = ?, appears_vs_reality = ?, appears_text = ?,
        reality_text = ?, personality = ?, age = ?, life_status = ?
      WHERE id = ?
    ''';
    final args = [
      c.name,
      c.role,
      c.volumeAppearances,
      c.notes,
      c.profileImagePath,
      c.statusRole,
      c.overallVibes,
      c.appearsVsReality,
      c.appearsText,
      c.realityText,
      c.personality,
      c.age,
      c.lifeStatus,
      c.id,
    ];
    await _turso.execute(sql, args);
  }

  Future<void> charactersDelete(int id) async {
    await _turso.batch([
      MapEntry(
        'DELETE FROM relationships WHERE from_character_id = ? OR to_character_id = ?',
        [id, id],
      ),
      MapEntry('DELETE FROM characters WHERE id = ?', [id]),
    ]);
  }

  // ─── Relationships ──────────────────────────────────────────────────

  Future<List<Relationship>> relationshipsGetBySeries(int seriesId) async {
    final sql = '''
      SELECT r.*,
        c1.name as from_character_name, c1.profile_image_path as from_character_image,
        c2.name as to_character_name, c2.profile_image_path as to_character_image
      FROM relationships r
      JOIN characters c1 ON r.from_character_id = c1.id
      JOIN characters c2 ON r.to_character_id = c2.id
      WHERE c1.series_id = ?
    ''';
    final res = await _turso.execute(sql, [seriesId]);
    return res.rows.map((r) => Relationship.fromJson(r)).toList();
  }

  Future<int> relationshipsCreate(Relationship rel) async {
    final sql = '''
      INSERT INTO relationships (
        from_character_id, to_character_id, type, label, is_bidirectional, notes
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''';
    final args = [
      rel.fromCharacterId,
      rel.toCharacterId,
      rel.type,
      rel.label,
      rel.isBidirectional ? 1 : 0,
      rel.notes,
    ];
    final res = await _turso.execute(sql, args);
    return res.lastInsertRowid ?? 0;
  }

  Future<void> relationshipsDelete(int id) async {
    await _turso.execute('DELETE FROM relationships WHERE id = ?', [id]);
  }

  // ─── Gallery Images & Links ─────────────────────────────────────────

  Future<List<GalleryImage>> galleryGetBySeries(int seriesId) async {
    final res = await _turso.execute(
      'SELECT * FROM gallery_images WHERE series_id = ? ORDER BY position, id',
      [seriesId],
    );
    return res.rows.map((r) => GalleryImage.fromJson(r)).toList();
  }

  Future<int> galleryAdd(GalleryImage img) async {
    final res = await _turso.execute('''
      INSERT INTO gallery_images (series_id, image_path, caption, position)
      VALUES (?, ?, ?, ?)
    ''', [img.seriesId, img.imagePath, img.caption, img.position]);
    return res.lastInsertRowid ?? 0;
  }

  Future<void> galleryDelete(int id) async {
    await _turso.execute('DELETE FROM gallery_images WHERE id = ?', [id]);
  }

  Future<List<LinkAttachment>> linksGetBySeries(int seriesId) async {
    final res = await _turso.execute(
      'SELECT * FROM link_attachments WHERE series_id = ? ORDER BY id DESC',
      [seriesId],
    );
    return res.rows.map((r) => LinkAttachment.fromJson(r)).toList();
  }

  Future<int> linksAdd(LinkAttachment link) async {
    final res = await _turso.execute('''
      INSERT INTO link_attachments (series_id, url, label)
      VALUES (?, ?, ?)
    ''', [link.seriesId, link.url, link.label]);
    return res.lastInsertRowid ?? 0;
  }

  Future<void> linksUpdate(LinkAttachment link) async {
    await _turso.execute(
      'UPDATE link_attachments SET url = ?, label = ? WHERE id = ?',
      [link.url, link.label, link.id],
    );
  }

  Future<void> linksDelete(int id) async {
    await _turso.execute('DELETE FROM link_attachments WHERE id = ?', [id]);
  }

  // ─── Attachments ───────────────────────────────────────────────────

  Future<List<Attachment>> attachmentsGetBySeries(int seriesId) async {
    final res = await _turso.execute(
      'SELECT * FROM attachments WHERE series_id = ? ORDER BY created_at DESC, id DESC',
      [seriesId],
    );
    return res.rows.map((r) => Attachment.fromJson(r)).toList();
  }

  Future<int> attachmentsAdd(Attachment attachment) async {
    final res = await _turso.execute('''
      INSERT INTO attachments (series_id, file_path, file_name, file_size)
      VALUES (?, ?, ?, ?)
    ''', [
      attachment.seriesId,
      attachment.filePath,
      attachment.fileName,
      attachment.fileSize,
    ]);
    return res.lastInsertRowid ?? 0;
  }

  Future<void> attachmentsDelete(int id) async {
    await _turso.execute('DELETE FROM attachments WHERE id = ?', [id]);
  }

  // ─── Glossary ───────────────────────────────────────────────────────

  Future<List<GlossaryTerm>> glossaryGetBySeries(int seriesId) async {
    final res = await _turso.execute(
      'SELECT * FROM glossary_terms WHERE series_id = ? ORDER BY term COLLATE NOCASE',
      [seriesId],
    );
    return res.rows.map((r) => GlossaryTerm.fromJson(r)).toList();
  }

  Future<int> glossaryAdd(GlossaryTerm term) async {
    final res = await _turso.execute('''
      INSERT INTO glossary_terms (series_id, term, definition)
      VALUES (?, ?, ?)
    ''', [term.seriesId, term.term, term.definition]);
    return res.lastInsertRowid ?? 0;
  }

  Future<void> glossaryUpdate(GlossaryTerm term) async {
    await _turso.execute('''
      UPDATE glossary_terms SET term = ?, definition = ? WHERE id = ?
    ''', [term.term, term.definition, term.id]);
  }

  Future<void> glossaryDelete(int id) async {
    await _turso.execute('DELETE FROM glossary_terms WHERE id = ?', [id]);
  }

  // ─── Metadata Lists ─────────────────────────────────────────────────

  Future<List<Tag>> tagsGetAll(String ownerId) async {
    final res = await _turso.execute(
      'SELECT * FROM tags WHERE owner_id = ? ORDER BY name COLLATE NOCASE',
      [ownerId],
    );
    return res.rows.map((r) => Tag.fromJson(r)).toList();
  }

  Future<List<Genre>> genresGetAll() async {
    final res = await _turso.execute(
      'SELECT * FROM genres ORDER BY name COLLATE NOCASE',
    );
    return res.rows.map((r) => Genre.fromJson(r)).toList();
  }

  Future<List<ContentWarning>> contentWarningsGetAll(String ownerId) async {
    final res = await _turso.execute(
      'SELECT * FROM content_warnings WHERE owner_id = ? ORDER BY name COLLATE NOCASE',
      [ownerId],
    );
    return res.rows.map((r) => ContentWarning.fromJson(r)).toList();
  }

  // ─── App Settings ───────────────────────────────────────────────────

  Future<Map<String, String>> settingsGetAll(String ownerId) async {
    final res = await _turso.execute(
      'SELECT key, value FROM app_settings WHERE owner_id = ?',
      [ownerId],
    );
    final map = <String, String>{};
    for (final r in res.rows) {
      if (r['key'] != null && r['value'] != null) {
        map[r['key'].toString()] = r['value'].toString();
      }
    }
    return map;
  }

  Future<void> settingsSet(String ownerId, String key, String value) async {
    await _turso.execute('''
      INSERT INTO app_settings (owner_id, key, value) VALUES (?, ?, ?)
      ON CONFLICT(owner_id, key) DO UPDATE SET value = excluded.value
    ''', [ownerId, key, value]);
  }
}
