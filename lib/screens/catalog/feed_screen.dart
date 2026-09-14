import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/library.dart';
import '../../models/metadata.dart';
import '../../models/series.dart';
import '../../providers/app_providers.dart';
import '../../theme/colors.dart';
import '../../widgets/series_card.dart';

/// Catalog Feed screen matching the wireframe layout.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _filterSeriesGroup = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterBottomSheet() {
    final filter = ref.read(seriesFilterProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sort & Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SORT BY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.darkTextMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildSortChip('Title A-Z', 'title', true, filter),
                      _buildSortChip('Title Z-A', 'title', false, filter),
                      _buildSortChip('Highest Rated', 'rating', false, filter),
                      _buildSortChip('Recently Added', 'id', false, filter),
                    ],
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
                            foregroundColor: AppColors.darkTextMuted,
                            side: const BorderSide(color: AppColors.darkBorder),
                          ),
                          child: const Text('Reset All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
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
  ) {
    final isSelected =
        currentFilter.sortBy == sortBy && currentFilter.sortAsc == sortAsc;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFF1B2338),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.darkTextMuted,
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
    final seriesAsync = ref.watch(seriesListProvider);
    final librariesAsync = ref.watch(librariesProvider);
    final selectedLibId = ref.watch(selectedLibraryIdProvider);
    final filter = ref.watch(seriesFilterProvider);

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
      backgroundColor: const Color(0xFF0C101A), // Deep dark background from wireframe
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/series/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Top Horizontal Category Tabs (Wireframe) ─────────────
            _buildCategoryTabs(librariesAsync, selectedLibId),
            const SizedBox(height: 14),

            // ── 2. Library Header Title & Count ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    libraryTitle,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  seriesAsync.when(
                    data: (list) {
                      final count = _filteredList(list).length;
                      return Text(
                        '$count ${count == 1 ? 'entry' : 'entries'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8A93A6),
                          fontWeight: FontWeight.w400,
                        ),
                      );
                    },
                    loading: () => const Text(
                      'Loading entries...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8A93A6)),
                    ),
                    error: (_, __) => const Text(
                      '0 entries',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8A93A6)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── 3. Search Bar + Purple Filter Button ─────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Row(
                children: [
                  // Search Text Input
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141926),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF232B40),
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          ref.read(seriesFilterProvider.notifier).state =
                              filter.copyWith(search: val);
                        },
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search title, author, fandom...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF6B7589),
                            fontSize: 13.5,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF6B7589),
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Color(0xFF6B7589),
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

                  // Purple Filter Square Button
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary, // Vibrant purple from wireframe
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.filter_alt_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      tooltip: 'Sort & Filters',
                      onPressed: _openFilterBottomSheet,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 4. Filter Chips Row: [ ] Series Group ▾ | All | Status ───
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Row(
                children: [
                  // Series Group Dropdown / Toggle Chip
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterSeriesGroup = !_filterSeriesGroup;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _filterSeriesGroup
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : const Color(0xFF141926),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _filterSeriesGroup
                              ? AppColors.primaryLight
                              : const Color(0xFF232B40),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _filterSeriesGroup
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 15,
                            color: _filterSeriesGroup
                                ? AppColors.primaryLight
                                : const Color(0xFF8A93A6),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Series Group',
                            style: TextStyle(
                              fontSize: 12,
                              color: _filterSeriesGroup
                                  ? Colors.white
                                  : const Color(0xFF8A93A6),
                              fontWeight: _filterSeriesGroup
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 16,
                            color: Color(0xFF8A93A6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // "All" Pill Chip
                  _buildStatusChip('All', filter.status == 'All', () {
                    ref.read(seriesFilterProvider.notifier).state =
                        filter.copyWith(status: 'All');
                  }),
                  const SizedBox(width: 8),

                  // Status Chips (Reading, Completed, On Hold, Planning, Dropped)
                  ...ReadingStatus.all.map((status) {
                    final isSelected = filter.status == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildStatusChip(status, isSelected, () {
                        ref.read(seriesFilterProvider.notifier).state =
                            filter.copyWith(status: status);
                      }),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── 5. Series Grid (2-Column Wireframe) ──────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(seriesListProvider);
                  ref.invalidate(librariesProvider);
                },
                color: AppColors.primaryLight,
                child: seriesAsync.when(
                  data: (seriesList) {
                    final items = _filteredList(seriesList);

                    if (items.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return SeriesCard(
                          series: item,
                          isGrid: true,
                          onTap: () => context.push('/series/${item.id}'),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryLight),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Failed to load: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.darkTextMuted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Series> _filteredList(List<Series> source) {
    if (!_filterSeriesGroup) return source;
    // Filter to series groups only if toggle is enabled
    return source.where((s) => s.kind == 'group' || s.kind == 'series').toList();
  }

  // ── Top Horizontal Categories Bar ────────────────────────────────────────

  Widget _buildCategoryTabs(
    AsyncValue<List<Library>> librariesAsync,
    int? selectedLibId,
  ) {
    return librariesAsync.when(
      data: (libraries) {
        final tabs = [
          const MapEntry<int?, String>(null, 'Library'),
          ...libraries.map((l) => MapEntry<int?, String>(l.id, l.name)),
        ];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
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
                        ? const Border(
                            bottom: BorderSide(
                              color: AppColors.primaryLight,
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
                          ? AppColors.primaryLight
                          : const Color(0xFF7A8396),
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

  Widget _buildStatusChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary // Solid purple from wireframe
              : const Color(0xFF141926),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryLight
                : const Color(0xFF232B40),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF8A93A6),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 32,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Entries Found',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No series match your current filter. Try selecting "All" or add a new book.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF8A93A6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/series/add'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
