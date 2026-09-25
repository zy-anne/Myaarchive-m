import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/metadata.dart';
import '../providers/app_providers.dart';
import '../theme/app_palette.dart';

/// Interactive search and filter header for the series catalog.
class SearchFilterBar extends ConsumerStatefulWidget {
  const SearchFilterBar({super.key});

  @override
  ConsumerState<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends ConsumerState<SearchFilterBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(seriesFilterProvider);
    final viewMode = ref.watch(viewModeProvider);
    final librariesAsync = ref.watch(librariesProvider);
    final selectedLibId = ref.watch(selectedLibraryIdProvider);
    final palette = context.palette;

    return Column(
      children: [
        // Search Input Row + View Mode Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // Search Input Field
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: palette.border,
                      width: 1,
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
                        fontSize: 13,
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
                                ref.read(seriesFilterProvider.notifier).state =
                                    filter.copyWith(search: '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // View Mode Toggle Button
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: palette.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: palette.border,
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    viewMode == ViewMode.grid
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    color: palette.accent,
                    size: 20,
                  ),
                  onPressed: () {
                    ref.read(viewModeProvider.notifier).state =
                        viewMode == ViewMode.grid
                            ? ViewMode.list
                            : ViewMode.grid;
                  },
                ),
              ),
            ],
          ),
        ),

        // Library & Status Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              // Library Selector Dropdown Pill
              librariesAsync.when(
                data: (libraries) {
                  if (libraries.isEmpty) return const SizedBox.shrink();
                  final currentLib = libraries.firstWhere(
                    (l) => l.id == selectedLibId,
                    orElse: () => libraries.first,
                  );

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: palette.primary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: PopupMenuButton<int?>(
                      initialValue: selectedLibId,
                      onSelected: (id) {
                        ref.read(selectedLibraryIdProvider.notifier).state = id;
                      },
                      color: palette.surfaceLight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.collections_bookmark_rounded,
                            size: 14,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            selectedLibId == null
                                ? 'All Libraries'
                                : currentLib.name,
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 16,
                            color: palette.primary,
                          ),
                        ],
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem<int?>(
                          value: null,
                          child: Text('All Libraries'),
                        ),
                        ...libraries.map(
                          (l) => PopupMenuItem<int?>(
                            value: l.id,
                            child: Text(l.name),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Status Filter Chips
              _buildFilterChip('All', filter.status == 'All', () {
                ref.read(seriesFilterProvider.notifier).state =
                    filter.copyWith(status: 'All');
              }, palette),
              ...ReadingStatus.all.map((status) {
                final isSelected = filter.status == status;
                return _buildFilterChip(status, isSelected, () {
                  ref.read(seriesFilterProvider.notifier).state =
                      filter.copyWith(status: status);
                }, palette);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? palette.onSolid : palette.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: palette.surfaceLight,
        selectedColor: palette.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? palette.accent
                : palette.border,
            width: 1,
          ),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }
}
