import 'metadata.dart';

/// Full Series / Book entry model matching Myaarchive Electron schema.
///
/// Includes all 26+ metadata fields, tag/genre associations, and subquery counters.
class Series {
  final int id;
  final String title;
  final String? author;
  final String status;
  final String? synopsis;
  final int libraryId;
  final String kind;
  final String? overallThoughts;
  final String? chapterThoughts;
  final String? coverImagePath;

  // Book Detail Expansion Fields
  final String? bookType;
  final int? rating;
  final String? originalLanguage;
  final String? countryOfOrigin;
  final String languageRead;
  final String? artist;
  final String? yearPublished;
  final String? dateStarted;
  final String? dateFinished;
  final String? statusCountryOfOrigin;
  final String? licensedEnglish;
  final String? completelyTranslated;
  final String? originalPublisher;
  final String? englishPublisher;
  final bool isNsfw;
  final int? standaloneChapterCount;
  final String? fandom;

  // Associated relational data
  final List<Tag> tags;
  final List<Genre> genres;
  final List<ContentWarning> contentWarnings;
  final int volumeCount;
  final int characterCount;

  const Series({
    required this.id,
    required this.title,
    this.author,
    this.status = 'Planning',
    this.synopsis,
    required this.libraryId,
    this.kind = 'series',
    this.overallThoughts,
    this.chapterThoughts,
    this.coverImagePath,
    this.bookType,
    this.rating,
    this.originalLanguage,
    this.countryOfOrigin,
    this.languageRead = 'English',
    this.artist,
    this.yearPublished,
    this.dateStarted,
    this.dateFinished,
    this.statusCountryOfOrigin,
    this.licensedEnglish,
    this.completelyTranslated,
    this.originalPublisher,
    this.englishPublisher,
    this.isNsfw = false,
    this.standaloneChapterCount,
    this.fandom,
    this.tags = const [],
    this.genres = const [],
    this.contentWarnings = const [],
    this.volumeCount = 0,
    this.characterCount = 0,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    // Parse tag_data string (id::name::color||id::name::color)
    final List<Tag> parsedTags = [];
    final tagData = json['tag_data']?.toString();
    if (tagData != null && tagData.isNotEmpty) {
      for (final entry in tagData.split('||')) {
        if (entry.isEmpty) continue;
        final parts = entry.split('::');
        if (parts.length >= 2) {
          final id = int.tryParse(parts[0]) ?? 0;
          final name = parts[1];
          final color = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : '#4a90e2';
          parsedTags.add(Tag(id: id, name: name, color: color));
        }
      }
    }

    // Parse genre_data string
    final List<Genre> parsedGenres = [];
    final genreData = json['genre_data']?.toString();
    if (genreData != null && genreData.isNotEmpty) {
      for (final entry in genreData.split('||')) {
        if (entry.isEmpty) continue;
        final parts = entry.split('::');
        if (parts.length >= 2) {
          final id = int.tryParse(parts[0]) ?? 0;
          final name = parts[1];
          final color = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : '#b2bec3';
          parsedGenres.add(Genre(id: id, name: name, color: color));
        }
      }
    }

    // Parse warning_data string
    final List<ContentWarning> parsedWarnings = [];
    final warningData = json['warning_data']?.toString();
    if (warningData != null && warningData.isNotEmpty) {
      for (final entry in warningData.split('||')) {
        if (entry.isEmpty) continue;
        final parts = entry.split('::');
        if (parts.length >= 2) {
          final id = int.tryParse(parts[0]) ?? 0;
          final name = parts[1];
          parsedWarnings.add(ContentWarning(id: id, name: name));
        }
      }
    }

    final nsfwRaw = json['is_nsfw'];
    final isNsfw = nsfwRaw == true || nsfwRaw == 1 || nsfwRaw == '1';

    return Series(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? 'Untitled',
      author: json['author']?.toString(),
      status: json['status']?.toString() ?? 'Planning',
      synopsis: json['synopsis']?.toString(),
      libraryId: json['library_id'] is int
          ? json['library_id']
          : int.tryParse(json['library_id'].toString()) ?? 1,
      kind: json['kind']?.toString() ?? 'series',
      overallThoughts: json['overall_thoughts']?.toString(),
      chapterThoughts: json['chapter_thoughts']?.toString(),
      coverImagePath: json['cover_image_path']?.toString(),
      bookType: json['book_type']?.toString(),
      rating: json['rating'] is int ? json['rating'] : int.tryParse(json['rating']?.toString() ?? ''),
      originalLanguage: json['original_language']?.toString(),
      countryOfOrigin: json['country_of_origin']?.toString(),
      languageRead: json['language_read']?.toString() ?? 'English',
      artist: json['artist']?.toString(),
      yearPublished: json['year_published']?.toString(),
      dateStarted: json['date_started']?.toString(),
      dateFinished: json['date_finished']?.toString(),
      statusCountryOfOrigin: json['status_country_of_origin']?.toString(),
      licensedEnglish: json['licensed_english']?.toString(),
      completelyTranslated: json['completely_translated']?.toString(),
      originalPublisher: json['original_publisher']?.toString(),
      englishPublisher: json['english_publisher']?.toString(),
      isNsfw: isNsfw,
      standaloneChapterCount: json['standalone_chapter_count'] is int
          ? json['standalone_chapter_count']
          : int.tryParse(json['standalone_chapter_count']?.toString() ?? ''),
      fandom: json['fandom']?.toString(),
      tags: parsedTags,
      genres: parsedGenres,
      contentWarnings: parsedWarnings,
      volumeCount: json['volume_count'] is int
          ? json['volume_count']
          : int.tryParse(json['volume_count']?.toString() ?? '') ?? 0,
      characterCount: json['character_count'] is int
          ? json['character_count']
          : int.tryParse(json['character_count']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'status': status,
        'synopsis': synopsis,
        'library_id': libraryId,
        'kind': kind,
        'overall_thoughts': overallThoughts,
        'chapter_thoughts': chapterThoughts,
        'cover_image_path': coverImagePath,
        'book_type': bookType,
        'rating': rating,
        'original_language': originalLanguage,
        'country_of_origin': countryOfOrigin,
        'language_read': languageRead,
        'artist': artist,
        'year_published': yearPublished,
        'date_started': dateStarted,
        'date_finished': dateFinished,
        'status_country_of_origin': statusCountryOfOrigin,
        'licensed_english': licensedEnglish,
        'completely_translated': completelyTranslated,
        'original_publisher': originalPublisher,
        'english_publisher': englishPublisher,
        'is_nsfw': isNsfw ? 1 : 0,
        'standalone_chapter_count': standaloneChapterCount,
        'fandom': fandom,
      };

  Series copyWith({
    int? id,
    String? title,
    Object? author = _unset,
    String? status,
    Object? synopsis = _unset,
    int? libraryId,
    String? kind,
    Object? overallThoughts = _unset,
    Object? chapterThoughts = _unset,
    Object? coverImagePath = _unset,
    String? bookType,
    int? rating,
    Object? originalLanguage = _unset,
    Object? countryOfOrigin = _unset,
    String? languageRead,
    Object? artist = _unset,
    Object? yearPublished = _unset,
    Object? dateStarted = _unset,
    Object? dateFinished = _unset,
    Object? statusCountryOfOrigin = _unset,
    Object? licensedEnglish = _unset,
    Object? completelyTranslated = _unset,
    Object? originalPublisher = _unset,
    Object? englishPublisher = _unset,
    bool? isNsfw,
    int? standaloneChapterCount,
    Object? fandom = _unset,
    List<Tag>? tags,
    List<Genre>? genres,
    List<ContentWarning>? contentWarnings,
    int? volumeCount,
    int? characterCount,
  }) {
    return Series(
      id: id ?? this.id,
      title: title ?? this.title,
      author: identical(author, _unset) ? this.author : author as String?,
      status: status ?? this.status,
      synopsis: identical(synopsis, _unset) ? this.synopsis : synopsis as String?,
      libraryId: libraryId ?? this.libraryId,
      kind: kind ?? this.kind,
      overallThoughts: identical(overallThoughts, _unset) ? this.overallThoughts : overallThoughts as String?,
      chapterThoughts: identical(chapterThoughts, _unset) ? this.chapterThoughts : chapterThoughts as String?,
      coverImagePath: identical(coverImagePath, _unset) ? this.coverImagePath : coverImagePath as String?,
      bookType: bookType ?? this.bookType,
      rating: rating ?? this.rating,
      originalLanguage: identical(originalLanguage, _unset) ? this.originalLanguage : originalLanguage as String?,
      countryOfOrigin: identical(countryOfOrigin, _unset) ? this.countryOfOrigin : countryOfOrigin as String?,
      languageRead: languageRead ?? this.languageRead,
      artist: identical(artist, _unset) ? this.artist : artist as String?,
      yearPublished: identical(yearPublished, _unset) ? this.yearPublished : yearPublished as String?,
      dateStarted: identical(dateStarted, _unset) ? this.dateStarted : dateStarted as String?,
      dateFinished: identical(dateFinished, _unset) ? this.dateFinished : dateFinished as String?,
      statusCountryOfOrigin: identical(statusCountryOfOrigin, _unset) ? this.statusCountryOfOrigin : statusCountryOfOrigin as String?,
      licensedEnglish: identical(licensedEnglish, _unset) ? this.licensedEnglish : licensedEnglish as String?,
      completelyTranslated: identical(completelyTranslated, _unset) ? this.completelyTranslated : completelyTranslated as String?,
      originalPublisher: identical(originalPublisher, _unset) ? this.originalPublisher : originalPublisher as String?,
      englishPublisher: identical(englishPublisher, _unset) ? this.englishPublisher : englishPublisher as String?,
      isNsfw: isNsfw ?? this.isNsfw,
      standaloneChapterCount: standaloneChapterCount ?? this.standaloneChapterCount,
      fandom: identical(fandom, _unset) ? this.fandom : fandom as String?,
      tags: tags ?? this.tags,
      genres: genres ?? this.genres,
      contentWarnings: contentWarnings ?? this.contentWarnings,
      volumeCount: volumeCount ?? this.volumeCount,
      characterCount: characterCount ?? this.characterCount,
    );
  }
}

/// Sentinel so copyWith can distinguish "not passed" from an explicit null.
const Object _unset = Object();
