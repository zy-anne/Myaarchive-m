import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/metadata.dart';
import '../../models/series.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_palette.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/tag_chip.dart';

/// Form screen for creating or editing a series entry.
class SeriesFormScreen extends ConsumerStatefulWidget {
  final int? seriesId;

  const SeriesFormScreen({super.key, this.seriesId});

  @override
  ConsumerState<SeriesFormScreen> createState() => _SeriesFormScreenState();
}

class _SeriesFormScreenState extends ConsumerState<SeriesFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _authorCtrl;
  late TextEditingController _synopsisCtrl;
  late TextEditingController _coverPathCtrl;
  late TextEditingController _overallThoughtsCtrl;
  late TextEditingController _chapterThoughtsCtrl;

  // Extra book detail controllers
  late TextEditingController _artistCtrl;
  late TextEditingController _yearPublishedCtrl;
  late TextEditingController _dateStartedCtrl;
  late TextEditingController _dateFinishedCtrl;
  late TextEditingController _originalPublisherCtrl;
  late TextEditingController _englishPublisherCtrl;
  late TextEditingController _standaloneChapterCtrl;
  late TextEditingController _fandomCtrl;
  late TextEditingController _tagInputCtrl;
  late TextEditingController _genreInputCtrl;
  late TextEditingController _warningInputCtrl;

  int _selectedLibraryId = 1;
  String _selectedKind = 'series'; // 'series' or 'standalone'
  String _selectedStatus = ReadingStatus.planning;
  String _selectedBookType = 'Manga';
  String _selectedLanguageRead = 'English';
  String? _originalLanguage;
  String? _countryOfOrigin;
  int _rating = 0;
  bool _isNsfw = false;

  final List<String> _tags = [];
  final List<String> _genres = [];
  final List<String> _contentWarnings = [];

  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isInitialDataLoaded = false;

  final ImagePicker _picker = ImagePicker();

  String? _statusCountryOfOrigin;
  String? _licensedEnglish;
  String? _completelyTranslated;

  static const List<String> _bookTypes = [
    'Manga',
    'Light Novel',
    'Webtoon',
    'Webnovel',
    'Manhwa',
    'Manhua',
    'Comic',
    'Fanfic',
    'Other',
  ];

  static const List<String> _originStatuses = [
    'Releasing',
    'Completed',
    'Hiatus',
    'Cancelled',
    'Discontinued',
  ];

  static const List<String> _yesNoOptions = ['Yes', 'No'];

  List<String> get _availableBookTypes {
    if (_selectedBookType.isNotEmpty && !_bookTypes.contains(_selectedBookType)) {
      return [..._bookTypes, _selectedBookType];
    }
    return _bookTypes;
  }

  List<String?> _dropdownOptions(List<String> base, String? current) {
    final list = <String?>[null, ...base];
    if (current != null && current.isNotEmpty && !base.contains(current)) {
      list.add(current);
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _authorCtrl = TextEditingController();
    _synopsisCtrl = TextEditingController();
    _coverPathCtrl = TextEditingController();
    _overallThoughtsCtrl = TextEditingController();
    _chapterThoughtsCtrl = TextEditingController();
    _artistCtrl = TextEditingController();
    _yearPublishedCtrl = TextEditingController();
    _dateStartedCtrl = TextEditingController();
    _dateFinishedCtrl = TextEditingController();
    _originalPublisherCtrl = TextEditingController();
    _englishPublisherCtrl = TextEditingController();
    _standaloneChapterCtrl = TextEditingController();
    _fandomCtrl = TextEditingController();
    _tagInputCtrl = TextEditingController();
    _genreInputCtrl = TextEditingController();
    _warningInputCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialDataLoaded && widget.seriesId != null) {
      _loadExistingSeries();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _synopsisCtrl.dispose();
    _coverPathCtrl.dispose();
    _overallThoughtsCtrl.dispose();
    _chapterThoughtsCtrl.dispose();
    _artistCtrl.dispose();
    _yearPublishedCtrl.dispose();
    _dateStartedCtrl.dispose();
    _dateFinishedCtrl.dispose();
    _originalPublisherCtrl.dispose();
    _englishPublisherCtrl.dispose();
    _standaloneChapterCtrl.dispose();
    _fandomCtrl.dispose();
    _tagInputCtrl.dispose();
    _genreInputCtrl.dispose();
    _warningInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingSeries() async {
    _isInitialDataLoaded = true;
    final dataLayer = ref.read(dataLayerProvider);
    final series = await dataLayer.seriesGetById(widget.seriesId!);
    if (series == null || !mounted) return;

    setState(() {
      _titleCtrl.text = series.title;
      _authorCtrl.text = series.author ?? '';
      _synopsisCtrl.text = series.synopsis ?? '';
      _coverPathCtrl.text = series.coverImagePath ?? '';
      _overallThoughtsCtrl.text = series.overallThoughts ?? '';
      _chapterThoughtsCtrl.text = series.chapterThoughts ?? '';
      _artistCtrl.text = series.artist ?? '';
      _yearPublishedCtrl.text = series.yearPublished ?? '';
      _dateStartedCtrl.text = series.dateStarted ?? '';
      _dateFinishedCtrl.text = series.dateFinished ?? '';
      _originalPublisherCtrl.text = series.originalPublisher ?? '';
      _englishPublisherCtrl.text = series.englishPublisher ?? '';
      _standaloneChapterCtrl.text =
          series.standaloneChapterCount?.toString() ?? '';
      _fandomCtrl.text = series.fandom ?? '';

      _selectedLibraryId = series.libraryId;
      _selectedKind = series.kind;
      _selectedStatus = series.status;
      if (series.bookType != null && series.bookType!.trim().isNotEmpty) {
        _selectedBookType = series.bookType!.trim();
      }
      _selectedLanguageRead = series.languageRead;
      _originalLanguage = series.originalLanguage;
      _countryOfOrigin = series.countryOfOrigin;
      _statusCountryOfOrigin = series.statusCountryOfOrigin;
      _licensedEnglish = series.licensedEnglish;
      _completelyTranslated = series.completelyTranslated;
      _rating = series.rating ?? 0;
      _isNsfw = series.isNsfw;

      _tags.addAll(series.tags.map((t) => t.name));
      _genres.addAll(series.genres.map((g) => g.name));
      _contentWarnings.addAll(series.contentWarnings.map((cw) => cw.name));
    });
  }

  Future<void> _pickAndUploadCover() async {
    final palette = context.palette;
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      final bytes = await image.readAsBytes();
      final r2 = ref.read(r2ServiceProvider);
      final key = r2.makeKey('covers', image.name);
      final ext = image.name.toLowerCase();
      final contentType = ext.endsWith('.png')
          ? 'image/png'
          : ext.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      final uploadedKey = await r2.uploadBytes(
        key: key,
        bytes: bytes,
        contentType: contentType,
      );
      setState(() {
        _coverPathCtrl.text = uploadedKey;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cover uploaded to Cloudflare R2!'),
            backgroundColor: palette.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Fallback so the chosen cover still shows up this session even
          // though the upload failed. On mobile this is a real file path
          // CoverImage can read directly. On web it's a `blob:` object URL
          // — CoverImage renders that too, but it only lives in this
          // browser tab: it won't survive a reload and won't sync to
          // other devices until the upload issue below is fixed and the
          // cover is re-picked.
          _coverPathCtrl.text = image.path;
        });

        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? "Couldn't upload to cloud storage — showing a local "
                      'preview for now. This is usually a CORS setting on '
                      'the storage bucket, not something wrong with your '
                      'image.'
                  : "Couldn't upload to cloud storage — showing a local "
                      'preview for now. Check your connection and try '
                      'again.',
            ),
            backgroundColor: palette.accent,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Details',
              onPressed: () => showDialog(
                context: context,
                builder: (dctx) => AlertDialog(
                  backgroundColor: palette.surfaceLight,
                  title: const Text('Upload Error Details'),
                  content: SingleChildScrollView(
                    child: Text(
                      e.toString(),
                      style: TextStyle(
                          fontSize: 12, color: palette.textSecondary),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    final palette = context.palette;
    final isCreating = widget.seriesId == null;

    try {
      final dataLayer = ref.read(dataLayerProvider);
      final series = Series(
        id: widget.seriesId ?? 0,
        title: _titleCtrl.text.trim(),
        author: _authorCtrl.text.trim().isEmpty ? null : _authorCtrl.text.trim(),
        status: _selectedStatus,
        synopsis:
            _synopsisCtrl.text.trim().isEmpty ? null : _synopsisCtrl.text.trim(),
        libraryId: _selectedLibraryId,
        kind: _selectedKind,
        coverImagePath: _coverPathCtrl.text.trim().isEmpty
            ? null
            : _coverPathCtrl.text.trim(),
        bookType: _selectedBookType,
        rating: _rating > 0 ? _rating : null,
        originalLanguage: _originalLanguage,
        countryOfOrigin: _countryOfOrigin,
        languageRead: _selectedLanguageRead,
        artist: _artistCtrl.text.trim().isEmpty ? null : _artistCtrl.text.trim(),
        yearPublished: _yearPublishedCtrl.text.trim().isEmpty
            ? null
            : _yearPublishedCtrl.text.trim(),
        dateStarted: _dateStartedCtrl.text.trim().isEmpty
            ? null
            : _dateStartedCtrl.text.trim(),
        dateFinished: _dateFinishedCtrl.text.trim().isEmpty
            ? null
            : _dateFinishedCtrl.text.trim(),
        statusCountryOfOrigin: _statusCountryOfOrigin,
        licensedEnglish: _licensedEnglish,
        completelyTranslated: _completelyTranslated,
        originalPublisher: _originalPublisherCtrl.text.trim().isEmpty
            ? null
            : _originalPublisherCtrl.text.trim(),
        englishPublisher: _englishPublisherCtrl.text.trim().isEmpty
            ? null
            : _englishPublisherCtrl.text.trim(),
        isNsfw: _isNsfw,
        standaloneChapterCount: int.tryParse(_standaloneChapterCtrl.text.trim()),
        fandom: _fandomCtrl.text.trim().isEmpty ? null : _fandomCtrl.text.trim(),
        overallThoughts: _overallThoughtsCtrl.text.trim().isEmpty
            ? null
            : _overallThoughtsCtrl.text.trim(),
        chapterThoughts: _chapterThoughtsCtrl.text.trim().isEmpty
            ? null
            : _chapterThoughtsCtrl.text.trim(),
      );

      int? createdSeriesId;

      if (isCreating) {
        createdSeriesId = await dataLayer.seriesCreate(
          user.id,
          series,
          tagNames: _tags,
          genreNames: _genres,
          warningNames: _contentWarnings,
        );
      } else {
        await dataLayer.seriesUpdate(
          user.id,
          series,
          tagNames: _tags,
          genreNames: _genres,
          warningNames: _contentWarnings,
        );
        ref.invalidate(seriesDetailProvider(widget.seriesId!));
      }

      ref.invalidate(seriesListProvider);
      ref.invalidate(librariesProvider);

      if (mounted) {
        // Settings → "Auto-Open Detail Page After Adding": only applies to
        // a fresh create, not an edit — editing already returns to the
        // detail page it came from.
        final autoOpenDetail = ref.read(autoOpenDetailAfterAddProvider);
        if (isCreating &&
            autoOpenDetail &&
            createdSeriesId != null &&
            createdSeriesId > 0) {
          // Replace this form in the stack (rather than push) so the back
          // button from the detail page returns to the library, not to a
          // now-stale, already-submitted form.
          context.pushReplacement('/series/$createdSeriesId');
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: palette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final librariesAsync = ref.watch(librariesProvider);

    // Dynamic reading statuses (Settings → Manage Statuses), falling back
    // to the built-in 5 while loading or if the user has none.
    final statusesAsync = ref.watch(readingStatusesProvider);
    final statusNames = statusesAsync.maybeWhen(
      data: (list) =>
          list.isEmpty ? ReadingStatus.all : list.map((s) => s.name).toList(),
      orElse: () => ReadingStatus.all,
    );

    // Existing vocabulary, so Tags/Genres/Content Warnings can show what
    // already exists instead of leaving the person to guess and risk
    // near-duplicate names (e.g. "Sci-Fi" vs "SciFi").
    final existingTagNames = ref.watch(userTagsProvider).maybeWhen(
          data: (list) => list.map((t) => t.name).toList(),
          orElse: () => const <String>[],
        );
    final existingGenreNames = ref.watch(allGenresProvider).maybeWhen(
          data: (list) => list.map((g) => g.name).toList(),
          orElse: () => const <String>[],
        );
    final existingWarningNames =
        ref.watch(userContentWarningsProvider).maybeWhen(
              data: (list) => list.map((w) => w.name).toList(),
              orElse: () => const <String>[],
            );
    if (statusNames.isNotEmpty && !statusNames.contains(_selectedStatus)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedStatus = statusNames.first);
      });
    }

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: Text(
          widget.seriesId == null ? 'Add Series' : 'Edit Series',
        ),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _handleSave,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Save'),
            style: TextButton.styleFrom(foregroundColor: palette.accent),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Cover Image Picker Header
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 130,
                    height: 190,
                    decoration: BoxDecoration(
                      color: palette.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: _coverPathCtrl.text.isNotEmpty
                        ? CoverImage(
                            imagePath: _coverPathCtrl.text,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : Center(
                            child: Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 40,
                              color: palette.textSecondary,
                            ),
                          ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: FloatingActionButton.small(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      onPressed: _isUploadingImage ? null : _pickAndUploadCover,
                      child: _isUploadingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap camera icon to pick & upload cover image to R2',
                style: TextStyle(
                  color: palette.textSecondary.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title (Required)
            TextFormField(
              controller: _titleCtrl,
              style: TextStyle(color: palette.textMain),
              decoration: const InputDecoration(
                labelText: 'Title *',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),

            // Author
            TextFormField(
              controller: _authorCtrl,
              style: TextStyle(color: palette.textMain),
              decoration: const InputDecoration(
                labelText: 'Author / Creator',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 14),

            // Series / Standalone Type
            Text(
              'Type',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildKindOption(
                    label: 'Series',
                    description: 'Multiple volumes/chapters',
                    icon: Icons.menu_book_rounded,
                    value: 'series',
                    palette: palette,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKindOption(
                    label: 'Standalone',
                    description: 'One book, its own thoughts',
                    icon: Icons.auto_stories_rounded,
                    value: 'standalone',
                    palette: palette,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Library & Status Row
            Row(
              children: [
                // Library selector
                Expanded(
                  child: librariesAsync.when(
                    data: (libs) {
                      if (libs.isEmpty) return const SizedBox.shrink();
                      final currentLibId = libs.any((l) => l.id == _selectedLibraryId)
                          ? _selectedLibraryId
                          : libs.first.id;
                      return DropdownButtonFormField<int>(
                        key: ValueKey('lib_$currentLibId'),
                        initialValue: currentLibId,
                        isExpanded: true,
                        dropdownColor: palette.surfaceLight,
                        decoration: const InputDecoration(
                          labelText: 'Library',
                          prefixIcon: Icon(Icons.folder_rounded),
                        ),
                        items: libs
                            .map((l) => DropdownMenuItem(
                                  value: l.id,
                                  child: Text(l.name,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLibraryId = val);
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 12),

                // Status dropdown (dynamic — see Settings → Manage Statuses)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('status_$_selectedStatus'),
                    initialValue: statusNames.contains(_selectedStatus)
                        ? _selectedStatus
                        : (statusNames.isNotEmpty ? statusNames.first : null),
                    isExpanded: true,
                    dropdownColor: palette.surfaceLight,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.bookmark_rounded),
                    ),
                    items: statusNames
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Format & Rating Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('fmt_$_selectedBookType'),
                    initialValue: _availableBookTypes.contains(_selectedBookType)
                        ? _selectedBookType
                        : (_availableBookTypes.isNotEmpty ? _availableBookTypes.first : null),
                    isExpanded: true,
                    dropdownColor: palette.surfaceLight,
                    decoration: const InputDecoration(
                      labelText: 'Format',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: _availableBookTypes
                        .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBookType = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rating',
                          style: TextStyle(
                              fontSize: 12, color: palette.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: RatingStars(
                            rating: _rating,
                            size: 20,
                            onRatingChanged: (newRating) {
                              setState(() => _rating = newRating);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // NSFW Toggle
            SwitchListTile(
              title: const Text('Adult / 18+ Content'),
              subtitle: const Text('Flags entry with NSFW danger pill'),
              value: _isNsfw,
              activeThumbColor: palette.danger,
              tileColor: palette.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: palette.border),
              ),
              onChanged: (val) => setState(() => _isNsfw = val),
            ),
            const SizedBox(height: 20),

            // Synopsis
            TextFormField(
              controller: _synopsisCtrl,
              style: TextStyle(color: palette.textMain),
              decoration: const InputDecoration(
                labelText: 'Synopsis',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // Tags Section
            _buildChipInputSection(
              title: 'Tags',
              controller: _tagInputCtrl,
              items: _tags,
              palette: palette,
              existingOptions: existingTagNames,
              onAdd: (val) {
                if (!_tags.contains(val)) setState(() => _tags.add(val));
              },
              onRemove: (val) => setState(() => _tags.remove(val)),
            ),
            const SizedBox(height: 16),

            // Genres Section
            _buildChipInputSection(
              title: 'Genres',
              controller: _genreInputCtrl,
              items: _genres,
              palette: palette,
              existingOptions: existingGenreNames,
              onAdd: (val) {
                if (!_genres.contains(val)) setState(() => _genres.add(val));
              },
              onRemove: (val) => setState(() => _genres.remove(val)),
            ),
            const SizedBox(height: 16),

            // Content Warnings Section
            _buildChipInputSection(
              title: 'Content Warnings',
              controller: _warningInputCtrl,
              items: _contentWarnings,
              palette: palette,
              isWarning: true,
              existingOptions: existingWarningNames,
              onAdd: (val) {
                if (!_contentWarnings.contains(val)) {
                  setState(() => _contentWarnings.add(val));
                }
              },
              onRemove: (val) => setState(() => _contentWarnings.remove(val)),
            ),
            const SizedBox(height: 20),

            // Overall Thoughts
            TextFormField(
              controller: _overallThoughtsCtrl,
              style: TextStyle(color: palette.textMain),
              decoration: const InputDecoration(
                labelText: 'Overall Thoughts',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 14),

            // Chapter Thoughts
            TextFormField(
              controller: _chapterThoughtsCtrl,
              style: TextStyle(color: palette.textMain),
              decoration: const InputDecoration(
                labelText: 'Chapter Thoughts / Reading Log',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Extra Metadata Expansion tile
            ExpansionTile(
              title: const Text('Extra Book Details (Optional)'),
              tilePadding: EdgeInsets.zero,
              children: [
                if (_selectedBookType == 'Fanfic') ...[
                  TextFormField(
                    controller: _fandomCtrl,
                    decoration: const InputDecoration(labelText: 'Fandom'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _artistCtrl,
                  decoration: const InputDecoration(labelText: 'Artist / Illustrator'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _yearPublishedCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Year Published'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _standaloneChapterCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Standalone Chs'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateStartedCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Date Started'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _dateFinishedCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Date Finished'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _originalPublisherCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Original Publisher'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _englishPublisherCtrl,
                        decoration:
                            const InputDecoration(labelText: 'English Publisher'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey('origin_$_statusCountryOfOrigin'),
                        initialValue: _statusCountryOfOrigin,
                        dropdownColor: palette.surfaceLight,
                        decoration: const InputDecoration(labelText: 'Origin Status'),
                        items: _dropdownOptions(_originStatuses, _statusCountryOfOrigin)
                            .map((opt) => DropdownMenuItem<String?>(
                                  value: opt,
                                  child: Text(opt ?? 'None / Unknown',
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _statusCountryOfOrigin = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey('licensed_$_licensedEnglish'),
                        initialValue: _licensedEnglish,
                        dropdownColor: palette.surfaceLight,
                        decoration: const InputDecoration(labelText: 'Licensed in EN'),
                        items: _dropdownOptions(_yesNoOptions, _licensedEnglish)
                            .map((opt) => DropdownMenuItem<String?>(
                                  value: opt,
                                  child: Text(opt ?? 'Unknown',
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _licensedEnglish = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('translated_$_completelyTranslated'),
                  initialValue: _completelyTranslated,
                  dropdownColor: palette.surfaceLight,
                  decoration: const InputDecoration(labelText: 'Completely Translated'),
                  items: _dropdownOptions(_yesNoOptions, _completelyTranslated)
                      .map((opt) => DropdownMenuItem<String?>(
                            value: opt,
                            child: Text(opt ?? 'Unknown',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _completelyTranslated = val),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Entry',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKindOption({
    required String label,
    required String description,
    required IconData icon,
    required String value,
    required AppPalette palette,
  }) {
    final selected = _selectedKind == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedKind = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.18) : palette.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.accent : palette.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? palette.accent : palette.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected ? palette.accent : palette.textMain,
                    ),
                  ),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipInputSection({
    required String title,
    required TextEditingController controller,
    required List<String> items,
    required ValueChanged<String> onAdd,
    required ValueChanged<String> onRemove,
    required AppPalette palette,
    bool isWarning = false,
    List<String> existingOptions = const [],
  }) {
    final query = controller.text.trim().toLowerCase();
    // Live type-ahead: once the person starts typing, show matching
    // existing names (not already added) they can tap instead of typing
    // the whole thing out — and, more importantly, so they can see
    // whether a close match already exists before creating a near-dupe.
    final suggestions = query.isEmpty
        ? const <String>[]
        : existingOptions
            .where((o) =>
                !items.contains(o) && o.toLowerCase().contains(query))
            .take(6)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: palette.textSecondary,
              ),
            ),
            if (existingOptions.isNotEmpty) ...[
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _showExistingOptionsPicker(
                  title: title,
                  allOptions: existingOptions,
                  selected: items,
                  palette: palette,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.list_alt_rounded,
                          size: 14, color: palette.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Browse existing',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: TextStyle(color: palette.textMain, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add $title...',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (val) {
                  final trimmed = val.trim();
                  if (trimmed.isNotEmpty) {
                    onAdd(trimmed);
                    controller.clear();
                    setState(() {});
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle_outline,
                  color: palette.accent),
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  onAdd(trimmed);
                  controller.clear();
                  setState(() {});
                }
              },
            ),
          ],
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions.map((s) {
              return ActionChip(
                avatar: Icon(Icons.add_rounded, size: 14, color: palette.accent),
                label: Text(s, style: const TextStyle(fontSize: 11)),
                backgroundColor: palette.surfaceLight,
                side: BorderSide(color: palette.border),
                onPressed: () {
                  onAdd(s);
                  controller.clear();
                  setState(() {});
                },
              );
            }).toList(),
          ),
        ],
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((item) {
              return TagChip(
                label: item,
                isWarning: isWarning,
                onDeleted: () => onRemove(item),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  /// Full searchable list of every existing tag/genre/content-warning name,
  /// with checkboxes — opened from "Browse existing" so the person can see
  /// the whole vocabulary up front, not just type-ahead matches. [selected]
  /// is the same list instance as the form's `_tags`/`_genres`/
  /// `_contentWarnings`, mutated in place as items are checked/unchecked.
  Future<void> _showExistingOptionsPicker({
    required String title,
    required List<String> allOptions,
    required List<String> selected,
    required AppPalette palette,
  }) {
    final searchCtrl = TextEditingController();

    return showModalBottomSheet(
      context: context,
      backgroundColor: palette.surfaceLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final visible = query.isEmpty
                ? allOptions
                : allOptions
                    .where((o) => o.toLowerCase().contains(query))
                    .toList();

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, 20 + MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(sheetCtx).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Existing $title',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: palette.textMain,
                          ),
                        ),
                        if (selected.isNotEmpty)
                          TextButton(
                            onPressed: () => setSheetState(() {
                              setState(() => selected.clear());
                            }),
                            child: const Text('Clear All'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setSheetState(() {}),
                      style: TextStyle(color: palette.textMain, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search $title...',
                        isDense: true,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: allOptions.isEmpty
                          ? Center(
                              child: Text(
                                'None created yet — add one below and '
                                "it'll show up here next time.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: palette.textSecondary),
                              ),
                            )
                          : visible.isEmpty
                              ? Center(
                                  child: Text(
                                    'No matches for "$query"',
                                    style:
                                        TextStyle(color: palette.textSecondary),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: visible.length,
                                  itemBuilder: (context, index) {
                                    final name = visible[index];
                                    final isSel = selected.contains(name);
                                    return CheckboxListTile(
                                      value: isSel,
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      activeColor: palette.accent,
                                      title: Text(
                                        name,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: palette.textMain),
                                      ),
                                      onChanged: (_) {
                                        setSheetState(() {});
                                        setState(() {
                                          isSel
                                              ? selected.remove(name)
                                              : selected.add(name);
                                        });
                                      },
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.onSolid,
                        ),
                        child: Text(selected.isEmpty
                            ? 'Done'
                            : 'Done (${selected.length} selected)'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}