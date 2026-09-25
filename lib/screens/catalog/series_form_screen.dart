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

  static const List<String> _bookTypes = [
    'Manga',
    'Light Novel',
    'Webtoon',
    'Novel',
    'Manhwa',
    'Manhua',
    'Comic',
    'Fanfic',
    'Other',
  ];

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
      _selectedStatus = series.status;
      if (series.bookType != null) _selectedBookType = series.bookType!;
      _selectedLanguageRead = series.languageRead;
      _originalLanguage = series.originalLanguage;
      _countryOfOrigin = series.countryOfOrigin;
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
      final filename =
          'covers/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final uploadedKey = await r2.uploadBytes(
        key: filename,
        bytes: bytes,
        contentType: 'image/jpeg',
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
        // Fallback: save local path if offline
        _coverPathCtrl.text = image.path;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cloud upload skipped (using local image): $e'),
            backgroundColor: palette.accent,
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

      if (widget.seriesId == null) {
        await dataLayer.seriesCreate(
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
        context.pop();
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

            // Library & Status Row
            Row(
              children: [
                // Library selector
                Expanded(
                  child: librariesAsync.when(
                    data: (libs) {
                      if (libs.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<int>(
                        initialValue: libs.any((l) => l.id == _selectedLibraryId)
                            ? _selectedLibraryId
                            : libs.first.id,
                        dropdownColor: palette.surfaceLight,
                        decoration: const InputDecoration(
                          labelText: 'Library',
                          prefixIcon: Icon(Icons.folder_rounded),
                        ),
                        items: libs
                            .map((l) => DropdownMenuItem(
                                  value: l.id,
                                  child: Text(l.name),
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
                    initialValue: statusNames.contains(_selectedStatus)
                        ? _selectedStatus
                        : (statusNames.isNotEmpty ? statusNames.first : null),
                    dropdownColor: palette.surfaceLight,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.bookmark_rounded),
                    ),
                    items: statusNames
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
                    initialValue: _selectedBookType,
                    dropdownColor: palette.surfaceLight,
                    decoration: const InputDecoration(
                      labelText: 'Format',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: _bookTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
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
                        RatingStars(
                          rating: _rating,
                          size: 20,
                          onRatingChanged: (newRating) {
                            setState(() => _rating = newRating);
                          },
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

  Widget _buildChipInputSection({
    required String title,
    required TextEditingController controller,
    required List<String> items,
    required ValueChanged<String> onAdd,
    required ValueChanged<String> onRemove,
    required AppPalette palette,
    bool isWarning = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: palette.textSecondary,
          ),
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
                onSubmitted: (val) {
                  final trimmed = val.trim();
                  if (trimmed.isNotEmpty) {
                    onAdd(trimmed);
                    controller.clear();
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
                }
              },
            ),
          ],
        ),
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
}