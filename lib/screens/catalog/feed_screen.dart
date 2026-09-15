import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/library.dart';
import '../../models/metadata.dart';
import '../../models/series.dart';
import '../../models/series_group.dart';
import '../../providers/app_providers.dart';
import '../../theme/colors.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/series_card.dart';
import '../../widgets/status_badge.dart';

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
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(seriesListProvider);
            ref.invalidate(librariesProvider);
            if (selectedLibId != null) {
              ref.invalidate(seriesGroupsProvider(selectedLibId));
            }
          },
          color: AppColors.primaryLight,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 1. Top Horizontal Category Tabs (Wireframe) ─────────────
              SliverToBoxAdapter(
                child: _buildCategoryTabs(librariesAsync, selectedLibId),
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
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // ── 3. Search Bar + Purple Filter Button ─────────────────────
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
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // ── 5. Series Groups (umbrella / shared-universe cards) ──────
              if (selectedLibId != null)
                SliverToBoxAdapter(child: _buildGroupsSection(selectedLibId)),

              // ── 6. Series Grid (2-Column Wireframe) ──────────────────────
              seriesAsync.when(
                data: (seriesList) {
                  final items = _filteredList(seriesList);

                  if (items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context),
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
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryLight),
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
                        style: const TextStyle(color: AppColors.darkTextMuted),
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

  Widget _buildGroupsSection(int libraryId) {
    final groupsAsync = ref.watch(seriesGroupsProvider(libraryId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141926),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF232B40), width: 1.2),
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
                      color: AppColors.darkTextMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.workspaces_rounded,
                        size: 16, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    const Text(
                      'Series Groups',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    groupsAsync.when(
                      data: (groups) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2338),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${groups.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.darkTextMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showGroupEditorDialog(libraryId),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('New Group'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
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
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Text(
                        'No series groups yet — tap "New Group" to link related titles (sequels, spin-offs, shared universes).',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.darkTextMuted,
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      children: groups
                          .map((g) => _buildUmbrellaGroupCard(g, libraryId))
                          .toList(),
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Text(
                    'Failed to load groups: $e',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.darkTextMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUmbrellaGroupCard(SeriesGroup group, int libraryId) {
    final isOpen = _expandedGroupIds.contains(group.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2338),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B3650)),
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
                    color: AppColors.darkTextMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      group.groupType,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: AppColors.darkTextMuted,
                    tooltip: 'Edit Group',
                    onPressed: () =>
                        _showGroupEditorDialog(libraryId, existingGroup: group),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.darkTextMuted,
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
                      _buildSubBookCard(group.items[i]),
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

  Widget _buildSubBookCard(SeriesGroupItem item) {
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
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.primaryLight,
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
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
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
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.darkTextMuted,
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
    int libraryId, {
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
              backgroundColor: AppColors.darkSurfaceLight,
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
                      const Text(
                        'MEMBER TITLES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: AppColors.darkTextMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (draftItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'No titles added yet.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkTextMuted,
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
                                    value: item.groupRole,
                                    isDense: true,
                                    dropdownColor: AppColors.darkSurfaceLight,
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
                                  color: AppColors.darkTextMuted,
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
                              value: selectedToAdd,
                              isDense: true,
                              dropdownColor: AppColors.darkSurfaceLight,
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
                            icon: const Icon(Icons.add_circle_outline,
                                color: AppColors.primaryLight),
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
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: ctx,
                        builder: (confirmCtx) => AlertDialog(
                          backgroundColor: AppColors.darkSurfaceLight,
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
                                  backgroundColor: AppColors.error),
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
                      backgroundColor: AppColors.primary),
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
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu_book_rounded, size: 32, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Entries Found',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'No series match your current filter. Try selecting "All" or add a new book.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF8A93A6)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/series/add'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Entry'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}