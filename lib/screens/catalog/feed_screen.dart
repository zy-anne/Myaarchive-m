import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/library.dart';
import '../../models/metadata.dart';
import '../../models/series.dart';
import '../../models/series_group.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_palette.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/series_card.dart';
import '../../widgets/series_table_view.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/transfer_copy_dialog.dart';

/// Catalog Feed screen matching the wireframe layout.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _groupsSectionCollapsed = false;
  final Set<int> _expandedGroupIds = {};

  static const List<String> _bookTypeOptions = [
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
  static const List<String> _languageOptions = [
    'English',
    'Japanese',
    'Korean',
    'Chinese',
    'Other',
  ];
  static const List<String> _translationOptions = [
    'Yes',
    'No',
    'In Progress',
    'N/A',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _viewModeIcon(ViewMode mode) {
    switch (mode) {
      case ViewMode.grid:
        return Icons.grid_view_rounded;
      case ViewMode.list:
        return Icons.view_list_rounded;
      case ViewMode.table:
        return Icons.table_rows_rounded;
    }
  }

  ViewMode _nextViewMode(ViewMode mode) {
    switch (mode) {
      case ViewMode.grid:
        return ViewMode.list;
      case ViewMode.list:
        return ViewMode.table;
      case ViewMode.table:
        return ViewMode.grid;
    }
  }

  TextStyle _sectionLabelStyle(AppPalette palette) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: palette.textSecondary,
      );

  void _openFilterBottomSheet(AppPalette palette) {
    final filter = ref.read(seriesFilterProvider);
    final genresAsync = ref.read(allGenresProvider);
    final tagsAsync = ref.read(userTagsProvider);

    final selectedGenres = List<String>.from(filter.genres);
    final selectedTags = List<String>.from(filter.tags);
    GenreTagMatchMode matchMode = filter.matchMode;
    int minRating = filter.minRating ?? 0;
    final yearFromCtrl =
        TextEditingController(text: filter.yearFrom?.toString() ?? '');
    final yearToCtrl =
        TextEditingController(text: filter.yearTo?.toString() ?? '');
    final authorCtrl = TextEditingController(text: filter.author ?? '');
    final artistCtrl = TextEditingController(text: filter.artist ?? '');
    final publisherCtrl = TextEditingController(text: filter.publisher ?? '');
    final originalLanguageCtrl =
        TextEditingController(text: filter.originalLanguage ?? '');
    final countryCtrl =
        TextEditingController(text: filter.countryOfOrigin ?? '');
    String? bookType = filter.bookType;
    String? languageRead = filter.languageRead;
    String? translationStatus = filter.translationStatus;

    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surfaceLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, 32 + MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sort & Filters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: palette.textMain,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Sort ──────────────────────────────────────────
                    Text('SORT BY', style: _sectionLabelStyle(palette)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSortChip('Title A-Z', 'title', true, filter, palette),
                        _buildSortChip('Title Z-A', 'title', false, filter, palette),
                        _buildSortChip('Author A-Z', 'author', true, filter, palette),
                        _buildSortChip('Highest Rated', 'rating', false, filter, palette),
                        _buildSortChip('Year (Newest)', 'year', false, filter, palette),
                        _buildSortChip('Recently Started', 'date_started', false, filter, palette),
                        _buildSortChip('Recently Finished', 'date_finished', false, filter, palette),
                        _buildSortChip('Recently Added', 'id', false, filter, palette),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Genres ────────────────────────────────────────
                    genresAsync.when(
                      data: (genres) {
                        if (genres.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GENRES', style: _sectionLabelStyle(palette)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: genres.map((g) {
                                final isSel = selectedGenres.contains(g.name);
                                return FilterChip(
                                  label: Text(g.name, style: const TextStyle(fontSize: 12)),
                                  selected: isSel,
                                  onSelected: (_) => setModalState(() {
                                    isSel
                                        ? selectedGenres.remove(g.name)
                                        : selectedGenres.add(g.name);
                                  }),
                                  selectedColor: palette.primary,
                                  backgroundColor: palette.surface,
                                  labelStyle: TextStyle(
                                      color: isSel ? Colors.white : palette.textSecondary),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    // ── Tags ──────────────────────────────────────────
                    tagsAsync.when(
                      data: (tags) {
                        if (tags.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TAGS', style: _sectionLabelStyle(palette)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tags.map((t) {
                                final isSel = selectedTags.contains(t.name);
                                return FilterChip(
                                  label: Text(t.name, style: const TextStyle(fontSize: 12)),
                                  selected: isSel,
                                  onSelected: (_) => setModalState(() {
                                    isSel
                                        ? selectedTags.remove(t.name)
                                        : selectedTags.add(t.name);
                                  }),
                                  selectedColor: palette.primary,
                                  backgroundColor: palette.surface,
                                  labelStyle: TextStyle(
                                      color: isSel ? Colors.white : palette.textSecondary),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    if (selectedGenres.isNotEmpty || selectedTags.isNotEmpty) ...[
                      Row(
                        children: [
                          Text('Match: ',
                              style: TextStyle(fontSize: 12, color: palette.textSecondary)),
                          ChoiceChip(
                            label: const Text('Any', style: TextStyle(fontSize: 12)),
                            selected: matchMode == GenreTagMatchMode.any,
                            onSelected: (_) =>
                                setModalState(() => matchMode = GenreTagMatchMode.any),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('All', style: TextStyle(fontSize: 12)),
                            selected: matchMode == GenreTagMatchMode.all,
                            onSelected: (_) =>
                                setModalState(() => matchMode = GenreTagMatchMode.all),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Rating ────────────────────────────────────────
                    Text('MINIMUM RATING', style: _sectionLabelStyle(palette)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        RatingStars(
                          rating: minRating,
                          size: 24,
                          onRatingChanged: (r) => setModalState(() => minRating = r),
                        ),
                        if (minRating > 0)
                          TextButton(
                            onPressed: () => setModalState(() => minRating = 0),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Publication year range ────────────────────────
                    Text('PUBLICATION YEAR', style: _sectionLabelStyle(palette)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: yearFromCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'From', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: yearToCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'To', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Format / language ─────────────────────────────
                    Text('FORMAT & LANGUAGE', style: _sectionLabelStyle(palette)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: bookType,
                            isExpanded: true,
                            dropdownColor: palette.surfaceLight,
                            decoration: const InputDecoration(labelText: 'Book Type', isDense: true),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Any')),
                              ..._bookTypeOptions
                                  .map((b) => DropdownMenuItem<String?>(value: b, child: Text(b))),
                            ],
                            onChanged: (v) => setModalState(() => bookType = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: languageRead,
                            isExpanded: true,
                            dropdownColor: palette.surfaceLight,
                            decoration:
                                const InputDecoration(labelText: 'Language Read', isDense: true),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Any')),
                              ..._languageOptions
                                  .map((l) => DropdownMenuItem<String?>(value: l, child: Text(l))),
                            ],
                            onChanged: (v) => setModalState(() => languageRead = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: originalLanguageCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Original Language', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: countryCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Country of Origin', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: translationStatus,
                      isExpanded: true,
                      dropdownColor: palette.surfaceLight,
                      decoration:
                          const InputDecoration(labelText: 'Translation Status', isDense: true),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Any')),
                        ..._translationOptions
                            .map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
                      ],
                      onChanged: (v) => setModalState(() => translationStatus = v),
                    ),
                    const SizedBox(height: 16),

                    // ── People & publishers ───────────────────────────
                    Text('PEOPLE & PUBLISHERS', style: _sectionLabelStyle(palette)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: authorCtrl,
                      decoration: const InputDecoration(labelText: 'Author', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: artistCtrl,
                      decoration: const InputDecoration(labelText: 'Artist', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: publisherCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Publisher (Original or English)', isDense: true),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref.read(seriesFilterProvider.notifier).state =
                                  const SeriesFilter();
                              Navigator.pop(ctx);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.textSecondary,
                              side: BorderSide(color: palette.border),
                            ),
                            child: const Text('Reset All'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final currentFilter = ref.read(seriesFilterProvider);
                              ref.read(seriesFilterProvider.notifier).state =
                                  currentFilter.copyWith(
                                genres: selectedGenres,
                                tags: selectedTags,
                                matchMode: matchMode,
                                minRating: minRating > 0 ? minRating : null,
                                clearMinRating: minRating == 0,
                                yearFrom: int.tryParse(yearFromCtrl.text.trim()),
                                clearYearFrom: yearFromCtrl.text.trim().isEmpty,
                                yearTo: int.tryParse(yearToCtrl.text.trim()),
                                clearYearTo: yearToCtrl.text.trim().isEmpty,
                                bookType: bookType,
                                clearBookType: bookType == null,
                                languageRead: languageRead,
                                clearLanguageRead: languageRead == null,
                                originalLanguage: originalLanguageCtrl.text.trim().isEmpty
                                    ? null
                                    : originalLanguageCtrl.text.trim(),
                                clearOriginalLanguage:
                                    originalLanguageCtrl.text.trim().isEmpty,
                                countryOfOrigin: countryCtrl.text.trim().isEmpty
                                    ? null
                                    : countryCtrl.text.trim(),
                                clearCountryOfOrigin: countryCtrl.text.trim().isEmpty,
                                translationStatus: translationStatus,
                                clearTranslationStatus: translationStatus == null,
                                author: authorCtrl.text.trim(),
                                artist: artistCtrl.text.trim(),
                                publisher: publisherCtrl.text.trim(),
                              );
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
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

  Widget _buildSortChip(
    String label,
    String sortBy,
    bool sortAsc,
    SeriesFilter currentFilter,
    AppPalette palette,
  ) {
    final isSelected =
        currentFilter.sortBy == sortBy && currentFilter.sortAsc == sortAsc;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: palette.primary,
      backgroundColor: palette.surfaceHigh,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : palette.textSecondary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        ref.read(seriesFilterProvider.notifier).state = currentFilter.copyWith(
          sortBy: sortBy,
          sortAsc: sortAsc,
        );
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final seriesAsync = ref.watch(seriesListProvider);
    final librariesAsync = ref.watch(librariesProvider);
    final selectedLibId = ref.watch(selectedLibraryIdProvider);
    final filter = ref.watch(seriesFilterProvider);
    final viewMode = ref.watch(viewModeProvider);

    // Dynamic reading statuses (Settings → Manage Statuses), falling back
    // to the built-in 5 while loading or if the user has none.
    final statusesAsync = ref.watch(readingStatusesProvider);
    final statusNames = statusesAsync.maybeWhen(
      data: (list) =>
          list.isEmpty ? ReadingStatus.all : list.map((s) => s.name).toList(),
      orElse: () => ReadingStatus.all,
    );

    // Get current selected library name
    String libraryTitle = 'Library';
    if (librariesAsync.hasValue && selectedLibId != null) {
      final lib = librariesAsync.value?.firstWhere(
        (l) => l.id == selectedLibId,
        orElse: () => Library(id: 0, ownerId: '', name: 'Library'),
      );
      if (lib != null && lib.name.isNotEmpty) {
        libraryTitle = lib.name;
      }
    }

    return Scaffold(
      backgroundColor: palette.bg,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/series/add'),
        backgroundColor: palette.primary,
        foregroundColor: palette.onSolid,
        elevation: 4,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(seriesListProvider);
            ref.invalidate(librariesProvider);
            if (selectedLibId != null) {
              ref.invalidate(seriesGroupsProvider(selectedLibId));
            }
          },
          color: palette.accent,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 1. Top Horizontal Category Tabs (Wireframe) ─────────────
              SliverToBoxAdapter(
                child: _buildCategoryTabs(librariesAsync, selectedLibId, palette),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // ── 2. Library Header Title & Count ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        libraryTitle,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: palette.textMain,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      seriesAsync.when(
                        data: (list) {
                          final count = _filteredList(list).length;
                          return Text(
                            '$count ${count == 1 ? 'entry' : 'entries'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                          );
                        },
                        loading: () => Text(
                          'Loading entries...',
                          style: TextStyle(fontSize: 13, color: palette.textSecondary),
                        ),
                        error: (_, __) => Text(
                          '0 entries',
                          style: TextStyle(fontSize: 13, color: palette.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // ── 3. Search Bar + View Toggle + Filter Button ──────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Row(
                    children: [
                      // Search Text Input
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: palette.border,
                              width: 1.2,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              ref.read(seriesFilterProvider.notifier).state =
                                  filter.copyWith(search: val);
                            },
                            style: TextStyle(
                              color: palette.textMain,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search title, author, fandom...',
                              hintStyle: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 13.5,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: palette.textSecondary,
                                size: 20,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: palette.textSecondary,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref
                                            .read(seriesFilterProvider.notifier)
                                            .state = filter.copyWith(search: '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // View Mode Toggle (Grid → List → Table)
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.border, width: 1.2),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _viewModeIcon(viewMode),
                            color: palette.textSecondary,
                            size: 20,
                          ),
                          tooltip: 'Change view',
                          onPressed: () {
                            ref.read(viewModeProvider.notifier).state =
                                _nextViewMode(viewMode);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Purple Filter Square Button
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.filter_alt_rounded,
                                color: palette.onSolid,
                                size: 22,
                              ),
                              tooltip: 'Sort & Filters',
                              onPressed: () => _openFilterBottomSheet(palette),
                            ),
                            if (filter.hasAdvancedFilters)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: palette.gold,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: palette.primary, width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── 4. Filter Chips Row: All | Status ─────────────────────────
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Row(
                    children: [
                      // "All" Pill Chip
                      _buildStatusChip('All', filter.status == 'All', () {
                        ref.read(seriesFilterProvider.notifier).state =
                            filter.copyWith(status: 'All');
                      }, palette),
                      const SizedBox(width: 8),

                      // Status Chips (dynamic — see Settings → Manage Statuses)
                      ...statusNames.map((status) {
                        final isSelected = filter.status == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildStatusChip(status, isSelected, () {
                            ref.read(seriesFilterProvider.notifier).state =
                                filter.copyWith(status: status);
                          }, palette),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // ── 5. Series Groups (umbrella / shared-universe cards) ──────
              if (selectedLibId != null)
                SliverToBoxAdapter(child: _buildGroupsSection(selectedLibId, palette)),

              // ── 6. Series Grid / List / Table ─────────────────────────────
              seriesAsync.when(
                data: (seriesList) {
                  final items = _filteredList(seriesList);

                  if (items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context, palette),
                    );
                  }

                  if (viewMode == ViewMode.table) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: SeriesTableView(
                          items: items,
                          filter: filter,
                          onFilterChanged: (f) =>
                              ref.read(seriesFilterProvider.notifier).state = f,
                        ),
                      ),
                    );
                  }

                  if (viewMode == ViewMode.list) {
                    return SliverPadding(
                      padding: const EdgeInsets.only(bottom: 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = items[index];
                            return SeriesCard(
                              series: item,
                              isGrid: false,
                              onTap: () => context.push('/series/${item.id}'),
                              onLongPress: () =>
                                  showTransferCopyDialog(context, ref, item, palette),
                            );
                          },
                          childCount: items.length,
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.54,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = items[index];
                          return SeriesCard(
                            series: item,
                            isGrid: true,
                            onTap: () => context.push('/series/${item.id}'),
                            onLongPress: () =>
                                showTransferCopyDialog(context, ref, item, palette),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  );
                },
                loading: () => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: palette.accent),
                  ),
                ),
                error: (err, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Failed to load: $err',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Series> _filteredList(List<Series> source) => source;

  // ── Series Groups (Umbrella Groups / Shared Universes) ────────────────
  //
  // Mirrors the desktop app's collapsible "Series Groups" section: a set
  // of umbrella cards, each expandable to show its member titles tagged
  // by group_role (Main Story, Spin-off, Prequel, etc). Library-scoped.

  Widget _buildGroupsSection(int libraryId, AppPalette palette) {
    final groupsAsync = ref.watch(seriesGroupsProvider(libraryId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(
                  () => _groupsSectionCollapsed = !_groupsSectionCollapsed),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      _groupsSectionCollapsed
                          ? Icons.chevron_right_rounded
                          : Icons.expand_more_rounded,
                      color: palette.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.workspaces_rounded,
                        size: 16, color: palette.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Series Groups',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: palette.textMain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    groupsAsync.when(
                      data: (groups) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.surfaceHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${groups.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showGroupEditorDialog(libraryId, palette),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('New Group'),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.accent,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_groupsSectionCollapsed)
              groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Text(
                        'No series groups yet — tap "New Group" to link related titles (sequels, spin-offs, shared universes).',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      children: groups
                          .map((g) => _buildUmbrellaGroupCard(g, libraryId, palette))
                          .toList(),
                    ),
                  );
                },
                loading: () => Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.accent,
                      ),
                    ),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Text(
                    'Failed to load groups: $e',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUmbrellaGroupCard(SeriesGroup group, int libraryId, AppPalette palette) {
    final isOpen = _expandedGroupIds.contains(group.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              if (isOpen) {
                _expandedGroupIds.remove(group.id);
              } else {
                _expandedGroupIds.add(group.id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isOpen
                        ? Icons.expand_more_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: palette.textMain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      group.groupType,
                      style: TextStyle(
                        fontSize: 10,
                        color: palette.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: palette.textSecondary,
                    tooltip: 'Edit Group',
                    onPressed: () =>
                        _showGroupEditorDialog(libraryId, palette, existingGroup: group),
                  ),
                ],
              ),
            ),
          ),
          if (isOpen) ...[
            if (group.description != null && group.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  group.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            IntrinsicHeight(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    for (int i = 0; i < group.items.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      _buildSubBookCard(group.items[i], palette),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubBookCard(SeriesGroupItem item, AppPalette palette) {
    return SizedBox(
      width: 112,
      child: GestureDetector(
        onTap: () => context.push('/series/${item.seriesId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 0.72,
                    child: CoverImage(
                      imagePath: item.coverImagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 4,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.groupRole,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: palette.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: palette.textMain,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                StatusBadge(status: item.status, compact: true),
                if (item.kind != 'standalone' && item.volumeCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${item.volumeCount}v',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            if (item.rating != null && item.rating! > 0) ...[
              const SizedBox(height: 2),
              RatingStars(rating: item.rating, size: 10),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showGroupEditorDialog(
    int libraryId,
    AppPalette palette, {
    SeriesGroup? existingGroup,
  }) async {
    final nameCtrl = TextEditingController(text: existingGroup?.name ?? '');
    final typeCtrl = TextEditingController(
        text: existingGroup?.groupType ?? 'Series Group');
    final descCtrl =
        TextEditingController(text: existingGroup?.description ?? '');

    final draftItems = <SeriesGroupDraftItem>[
      if (existingGroup != null)
        ...existingGroup.items.map((i) => SeriesGroupDraftItem(
              seriesId: i.seriesId,
              title: i.title,
              groupRole: i.groupRole,
            )),
    ];

    // Independent, unfiltered fetch of this library's titles so the "add
    // book" picker isn't affected by the grid's active search/status filter.
    final dataLayer = ref.read(dataLayerProvider);
    final user = ref.read(authStateProvider).value;
    List<Series> libraryTitles = [];
    if (user != null) {
      libraryTitles =
          await dataLayer.seriesGetAll(user.id, libraryId: libraryId);
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final available = libraryTitles
                .where((s) =>
                    !draftItems.any((d) => d.seriesId == s.id))
                .toList();
            int? selectedToAdd;

            return AlertDialog(
              backgroundColor: palette.surfaceLight,
              title: Text(existingGroup == null
                  ? 'New Series Group / Universe'
                  : 'Edit Series Group / Universe'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Group Name *'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: typeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Group Type',
                          hintText: 'e.g. Shared Universe, Spin-off Collection',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'MEMBER TITLES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (draftItems.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'No titles added yet.',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                        )
                      else
                        ...draftItems.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: item.groupRole,
                                    isDense: true,
                                    dropdownColor: palette.surfaceLight,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                    ),
                                    items: GroupRoles.all
                                        .map((r) => DropdownMenuItem(
                                              value: r,
                                              child: Text(
                                                r,
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setDialogState(
                                          () => item.groupRole = val);
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 16),
                                  color: palette.textSecondary,
                                  onPressed: () => setDialogState(() =>
                                      draftItems.remove(item)),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedToAdd,
                              isDense: true,
                              dropdownColor: palette.surfaceLight,
                              hint: const Text(
                                '-- Select a title to add --',
                                style: TextStyle(fontSize: 12),
                              ),
                              decoration: const InputDecoration(isDense: true),
                              items: available
                                  .map((s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(
                                          s.title,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (val) =>
                                  setDialogState(() => selectedToAdd = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.add_circle_outline,
                                color: palette.accent),
                            onPressed: () {
                              if (selectedToAdd == null) return;
                              final series = libraryTitles
                                  .firstWhere((s) => s.id == selectedToAdd);
                              setDialogState(() {
                                draftItems.add(SeriesGroupDraftItem(
                                  seriesId: series.id,
                                  title: series.title,
                                ));
                                selectedToAdd = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (existingGroup != null)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: palette.danger),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: ctx,
                        builder: (confirmCtx) => AlertDialog(
                          backgroundColor: palette.surfaceLight,
                          title: const Text('Delete Group?'),
                          content: Text(
                            'Delete "${existingGroup.name}"? This won\'t delete the titles in it, just the group.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(confirmCtx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: palette.danger),
                              onPressed: () =>
                                  Navigator.pop(confirmCtx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(dataLayerProvider)
                            .seriesGroupsDelete(existingGroup.id);
                        ref.invalidate(seriesGroupsProvider(libraryId));
                        if (context.mounted) Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Delete'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    final itemPairs = draftItems
                        .map((d) => MapEntry(d.seriesId, d.groupRole))
                        .toList();

                    final dl = ref.read(dataLayerProvider);
                    if (existingGroup == null) {
                      await dl.seriesGroupsCreate(
                        libraryId: libraryId,
                        name: name,
                        groupType: typeCtrl.text.trim().isEmpty
                            ? 'Series Group'
                            : typeCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        items: itemPairs,
                      );
                    } else {
                      await dl.seriesGroupsUpdate(
                        existingGroup.id,
                        name: name,
                        groupType: typeCtrl.text.trim().isEmpty
                            ? 'Series Group'
                            : typeCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        items: itemPairs,
                      );
                    }
                    ref.invalidate(seriesGroupsProvider(libraryId));
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Top Horizontal Categories Bar ────────────────────────────────────────

  Widget _buildCategoryTabs(
    AsyncValue<List<Library>> librariesAsync,
    int? selectedLibId,
    AppPalette palette,
  ) {
    return librariesAsync.when(
      data: (libraries) {
        final tabs = [
          const MapEntry<int?, String>(null, 'Library'),
          ...libraries.map((l) => MapEntry<int?, String>(l.id, l.name)),
        ];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18.0, 14.0, 18.0, 0),
          child: Row(
            children: tabs.map((entry) {
              final isSelected = selectedLibId == entry.key;

              return GestureDetector(
                onTap: () {
                  ref.read(selectedLibraryIdProvider.notifier).state =
                      entry.key;
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 20),
                  padding: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    border: isSelected
                        ? Border(
                            bottom: BorderSide(
                              color: palette.accent,
                              width: 2.5,
                            ),
                          )
                        : null,
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? palette.accent
                          : palette.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const SizedBox(height: 28),
      error: (_, __) => const SizedBox(height: 28),
    );
  }

  Widget _buildStatusChip(String label, bool isSelected, VoidCallback onTap, AppPalette palette) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primary
              : palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? palette.accent
                : palette.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? palette.onSolid : palette.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

    Widget _buildEmptyState(BuildContext context, AppPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.menu_book_rounded, size: 32, color: palette.accent),
            ),
            const SizedBox(height: 16),
            Text(
              'No Entries Found',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: palette.textMain),
            ),
            const SizedBox(height: 6),
            Text(
              'No series match your current filter. Try selecting "All" or add a new book.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/series/add'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Entry'),
              style: ElevatedButton.styleFrom(backgroundColor: palette.primary, foregroundColor: palette.onSolid),
            ),
          ],
        ),
      ),
    );
  }
}