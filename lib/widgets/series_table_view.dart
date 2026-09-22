import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/series.dart';
import '../providers/app_providers.dart';
import '../theme/app_palette.dart';
import 'rating_stars.dart';
import 'status_badge.dart';

/// Dense, sortable table view of the library — an alternative to the
/// grid/list card views. Tapping a column header sorts by that column;
/// tapping the same header again reverses direction. Only columns backed
/// by a real `sortBy` key on [SeriesFilter] are sortable (Status, Format,
/// and Volumes are display-only).
class SeriesTableView extends StatelessWidget {
  final List<Series> items;
  final SeriesFilter filter;
  final ValueChanged<SeriesFilter> onFilterChanged;

  const SeriesTableView({
    super.key,
    required this.items,
    required this.filter,
    required this.onFilterChanged,
  });

  static const List<_ColumnDef> _columns = [
    _ColumnDef('Title', 'title'),
    _ColumnDef('Author', 'author'),
    _ColumnDef('Status', null),
    _ColumnDef('Rating', 'rating'),
    _ColumnDef('Format', null),
    _ColumnDef('Year', 'year'),
    _ColumnDef('Vols', null),
    _ColumnDef('Started', 'date_started'),
    _ColumnDef('Finished', 'date_finished'),
    _ColumnDef('Added', 'id'),
  ];

  int? get _sortColumnIndex {
    final i = _columns.indexWhere((c) => c.sortKey == filter.sortBy);
    return i == -1 ? null : i;
  }

  void _onSort(int columnIndex) {
    final key = _columns[columnIndex].sortKey;
    if (key == null) return;
    final ascending = filter.sortBy == key ? !filter.sortAsc : true;
    onFilterChanged(filter.copyWith(sortBy: key, sortAsc: ascending));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: _sortColumnIndex,
          sortAscending: filter.sortAsc,
          headingRowColor: WidgetStateProperty.all(palette.surfaceHigh),
          dataRowMinHeight: 44,
          dataRowMaxHeight: 56,
          columnSpacing: 22,
          horizontalMargin: 14,
          columns: _columns
              .map((c) => DataColumn(
                    label: Text(
                      c.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: palette.textMain,
                      ),
                    ),
                    onSort: c.sortKey == null
                        ? null
                        : (columnIndex, _) => _onSort(columnIndex),
                  ))
              .toList(),
          rows: items.map((s) {
            return DataRow(
              onSelectChanged: (_) => context.push('/series/${s.id}'),
              cells: [
                DataCell(
                  SizedBox(
                    width: 160,
                    child: Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: palette.textMain,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 110,
                    child: Text(
                      s.author ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontSize: 12),
                    ),
                  ),
                ),
                DataCell(StatusBadge(status: s.status, compact: true)),
                DataCell(RatingStars(rating: s.rating, size: 12)),
                DataCell(Text(
                  s.bookType ?? '—',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                )),
                DataCell(Text(
                  s.yearPublished ?? '—',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                )),
                DataCell(Text(
                  '${s.volumeCount}',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                )),
                DataCell(Text(
                  s.dateStarted ?? '—',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                )),
                DataCell(Text(
                  s.dateFinished ?? '—',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                )),
                DataCell(Text(
                  '#${s.id}',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ColumnDef {
  final String label;
  final String? sortKey;
  const _ColumnDef(this.label, this.sortKey);
}