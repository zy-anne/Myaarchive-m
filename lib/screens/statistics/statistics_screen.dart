import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/metadata.dart';
import '../../models/series.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_palette.dart';
import '../../widgets/radar_chart.dart';

/// Reading Statistics screen mirroring the web app's comprehensive analytics view.
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  void _showSetGoalDialog(String? currentGoal, AppPalette palette) {
    final controller = TextEditingController(text: currentGoal ?? '25');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: Text('Annual Reading Goal ($_selectedYear)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set target number of books/manga to complete this year:',
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(
                color: palette.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              decoration: InputDecoration(
                labelText: 'Target Works',
                suffixText: 'books',
                filled: true,
                fillColor: palette.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final val = int.tryParse(controller.text.trim());
              final navigator = Navigator.of(ctx);
              if (val != null && val > 0) {
                final user = ref.read(authStateProvider).value;
                if (user != null) {
                  await ref
                      .read(dataLayerProvider)
                      .settingsSet(user.id, 'annualReadingGoal', val.toString());
                  ref.invalidate(appSettingsProvider);
                }
              }
              if (mounted) navigator.pop();
            },
            child: const Text('Save Goal'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final seriesAsync = ref.watch(allSeriesForStatsProvider);
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: const Text('Reading Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(allSeriesForStatsProvider);
              ref.invalidate(appSettingsProvider);
            },
          ),
        ],
      ),
      body: seriesAsync.when(
        data: (seriesList) {
          if (seriesList.isEmpty) {
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
                      child: Icon(
                        Icons.bar_chart_rounded,
                        size: 36,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Reading Data Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: palette.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add titles to your library to track reading milestones, velocity, and genres.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          final settings = settingsAsync.value ?? {};
          final goalStr = settings['annualReadingGoal'];
          final int? goal = goalStr != null ? int.tryParse(goalStr) : null;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allSeriesForStatsProvider);
              ref.invalidate(appSettingsProvider);
            },
            color: palette.accent,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _buildMilestoneHero(seriesList, goal, palette),
                const SizedBox(height: 16),
                _buildQuickStatsGrid(seriesList, palette),
                const SizedBox(height: 20),
                _buildReadingTimelineCard(seriesList, palette),   // new
                const SizedBox(height: 20),
                _buildStatusDistributionCard(seriesList, palette),
                const SizedBox(height: 20),
                _buildRatingDistributionCard(seriesList, palette),
                const SizedBox(height: 20),
                _buildFormatDistributionCard(seriesList, palette),
                const SizedBox(height: 20),
                _buildTopGenresCard(seriesList, palette),
                const SizedBox(height: 20),
                _buildTopTagsCard(seriesList, palette),           // new
                const SizedBox(height: 20),
                _buildRadarCard(seriesList, palette),             // new
              ],
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.accent),
        ),
        error: (e, _) => Center(
          child: Text('Failed to load stats: $e'),
        ),
      ),
    );
  }

  int? _yearOf(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final s = dateStr.trim();

    // Try standard ISO parse first (handles "2026-09-15", "2026-09-15T..." etc.)
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.year;

    // Fallback: grabs the first 4-digit run, for hand-typed dates like "9/15/2026"
    final match = RegExp(r'(\d{4})').firstMatch(s);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }

    return null;
  }

  // ─── Data helpers — strict ISO date parsing for day-level accuracy ────

  /// Parses `dateFinished` to an exact calendar day. Unlike [_yearOf], this
  /// does NOT fall back to a fuzzy year-only regex — streaks, heatmaps, and
  /// weekly breakdowns need a real day, not just a year guess.
  DateTime? _parseFullDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final d = DateTime.tryParse(raw.trim());
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  List<Series> _finishedIn(List<Series> allSeries, int year, int? month) {
    return allSeries.where((s) {
      if (s.status != ReadingStatus.finished) return false;
      final d = _parseFullDate(s.dateFinished);
      if (d == null) return false;
      if (d.year != year) return false;
      if (month != null && d.month != month) return false;
      return true;
    }).toList();
  }

  Map<DateTime, int> _dailyFinishCounts(List<Series> allSeries) {
    final map = <DateTime, int>{};
    for (final s in allSeries) {
      if (s.status != ReadingStatus.finished) continue;
      final d = _parseFullDate(s.dateFinished);
      if (d == null) continue;
      map[d] = (map[d] ?? 0) + 1;
    }
    return map;
  }

  // ─── Streak / consistency math (all-time) ──────────────────────────────

  _ConsistencyStats _computeConsistency(Map<DateTime, int> daily) {
    if (daily.isEmpty) return const _ConsistencyStats(0, 0, 0, 0, 0);

    final activeDays = daily.keys.toList()..sort();
    int longestStreak = 1, running = 1, longestBreak = 0;
    for (int i = 1; i < activeDays.length; i++) {
      final gap = activeDays[i].difference(activeDays[i - 1]).inDays;
      if (gap == 1) {
        running++;
        longestStreak = math.max(longestStreak, running);
      } else {
        longestBreak = math.max(longestBreak, gap - 1);
        running = 1;
      }
    }

    final activeSet = activeDays.toSet();
    final today = DateTime.now();
    DateTime cursor = DateTime(today.year, today.month, today.day);
    if (!activeSet.contains(cursor)) {
      final past = activeDays.where((d) => !d.isAfter(cursor)).toList();
      if (past.isEmpty) {
        return _ConsistencyStats(0, longestStreak, longestBreak, activeDays.length, 0);
      }
      cursor = past.last;
    }
    int currentStreak = 0;
    while (activeSet.contains(cursor)) {
      currentStreak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final spanDays = activeDays.last.difference(activeDays.first).inDays + 1;
    final consistencyPct = spanDays > 0 ? (activeDays.length / spanDays) * 100 : 0.0;

    return _ConsistencyStats(currentStreak, longestStreak, longestBreak, activeDays.length, consistencyPct);
  }

  List<MapEntry<String, int>> _weeklyBreakdown(Map<DateTime, int> daily, int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final weeks = <MapEntry<String, int>>[];
    int weekNum = 1;
    for (int start = 1; start <= daysInMonth; start += 7) {
      final end = math.min(start + 6, daysInMonth);
      int count = 0;
      for (int day = start; day <= end; day++) {
        count += daily[DateTime(year, month, day)] ?? 0;
      }
      weeks.add(MapEntry('Week $weekNum (${end - start + 1}d)', count));
      weekNum++;
    }
    return weeks;
  }

  // ─── 1. Annual Milestone Hero ──────────────────────────────────────────

  Widget _buildMilestoneHero(List<Series> allSeries, int? goal, AppPalette palette) {
    final completedCount = allSeries.where((s) {
      if (s.status != ReadingStatus.finished) return false;
      return _yearOf(s.dateFinished) == _selectedYear;
    }).length;

    final progressPct = goal != null && goal > 0
        ? (completedCount / goal).clamp(0.0, 1.0)
        : 0.0;
    final pctText = (progressPct * 100).toInt();
    final remaining = goal != null ? (goal - completedCount).clamp(0, goal) : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.primary, palette.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ANNUAL MILESTONE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_selectedYear Reading Journey',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: Colors.white,
                tooltip: 'Set Reading Goal',
                onPressed: () => _showSetGoalDialog(goal?.toString(), palette),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (goal != null && goal > 0) ...[
            // Numbers row
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$completedCount',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'of',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  '$goal',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'works read',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pctText%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressPct,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 10),

            // Remaining text
            Text(
              remaining > 0
                  ? '$remaining more to reach your annual goal!'
                  : '🎉 Congratulations! You reached your reading goal!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            // Goal unset prompt
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No annual goal set yet for this year.',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showSetGoalDialog(null, palette),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: palette.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Set Goal', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 2. Quick Stats Grid ───────────────────────────────────────────────

  Widget _buildQuickStatsGrid(List<Series> allSeries, AppPalette palette) {
    int readingCount = 0;
    int planningCount = 0;
    int completedCount = 0;
    double ratingSum = 0;
    int ratedCount = 0;

    for (final s in allSeries) {
      final st = s.status;
      if (st == ReadingStatus.reading) readingCount++;
      if (st == ReadingStatus.planning) planningCount++;
      if (st == ReadingStatus.finished) completedCount++;

      if (s.rating != null && s.rating! > 0) {
        ratingSum += s.rating!;
        ratedCount++;
      }
    }

    final avgRating = ratedCount > 0
        ? (ratingSum / ratedCount).toStringAsFixed(1)
        : '—';

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      children: [
        _buildStatCard('Active', '$readingCount', 'Reading Now',
            palette.accent, Icons.menu_book_rounded, palette),
        _buildStatCard('Queued', '$planningCount', 'In Planning',
            palette.secondary, Icons.schedule_rounded, palette),
        _buildStatCard('Finished', '$completedCount', 'Completed',
            palette.success, Icons.check_circle_outline_rounded, palette),
        _buildStatCard('Avg Rating', avgRating, '$ratedCount rated titles',
            palette.gold, Icons.star_rounded, palette),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String subtitle,
    Color accentColor,
    IconData icon,
    AppPalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: palette.border.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: palette.textSecondary,
                ),
              ),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: palette.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Reading Timeline (monthly bar chart + drilldown)

  Map<int, int> _monthlyFinishedCounts(List<Series> allSeries, int year) {
    final counts = <int, int>{for (var m = 1; m <= 12; m++) m: 0};
    for (final s in allSeries) {
      if (s.status != ReadingStatus.finished) continue;
      final y = _yearOf(s.dateFinished);
      if (y != year) continue;
      final f = s.dateFinished;
      final parts = f?.split('-');
      final m = (parts != null && parts.length > 1) ? int.tryParse(parts[1]) : null;
      if (m != null && m >= 1 && m <= 12) {
        counts[m] = (counts[m] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<int> _availableYears(List<Series> allSeries) {
    final years = <int>{DateTime.now().year};
    for (final s in allSeries) {
      final f = s.dateFinished;
      if (f != null && f.length >= 4) {
        final y = int.tryParse(f.substring(0, 4));
        if (y != null) years.add(y);
      }
    }
    return (years.toList()..sort((a, b) => b.compareTo(a)));
  }

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Widget _buildReadingTimelineCard(List<Series> allSeries, AppPalette palette) {
    final counts = _monthlyFinishedCounts(allSeries, _selectedYear);
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('READING TIMELINE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      letterSpacing: 0.8, color: palette.textSecondary)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: _selectedYear,
                    dropdownColor: palette.surfaceLight,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(color: palette.accent,
                        fontSize: 12, fontWeight: FontWeight.w600),
                    items: _availableYears(allSeries)
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (y) { if (y != null) setState(() => _selectedYear = y); },
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: _selectedMonth,
                    dropdownColor: palette.surfaceLight,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(color: palette.accent,
                        fontSize: 12, fontWeight: FontWeight.w600),
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(_monthNames[m - 1]),
                            ))
                        .toList(),
                    onChanged: (m) { if (m != null) setState(() => _selectedMonth = m); },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) {
                final month = i + 1;
                final count = counts[month] ?? 0;
                final isPeak = maxCount > 0 && count == maxCount;
                final isSelected = month == _selectedMonth;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMonth = month),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 14,
                          child: count > 0
                              ? Center(
                                  child: Text('$count',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                          color: isPeak ? palette.accent : palette.textSecondary)))
                              : null,
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: maxCount > 0
                                  ? (count / maxCount).clamp(0.04, 1.0)
                                  : 0.02,
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: isPeak
                                      ? palette.accent
                                      : palette.primary.withValues(alpha: count > 0 ? 0.55 : 0.12),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                  border: isSelected
                                      ? Border.all(color: palette.accent, width: 1.5)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(months[i], style: TextStyle(
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? palette.accent : palette.textSecondary)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: palette.border),
          const SizedBox(height: 16),
          _buildMonthDrilldown(allSeries, _selectedYear, _selectedMonth, palette),
        ],
      ),
    );
  }

  // ─── 3b. Month Drilldown (completed count, streaks, weekly, heatmap) ──

  Widget _buildMonthDrilldown(List<Series> allSeries, int year, int month, AppPalette palette) {
    final monthSeries = _finishedIn(allSeries, year, month);
    final allDaily = _dailyFinishCounts(allSeries); // all-time, for consistency block
    final consistency = _computeConsistency(allDaily);
    final weeks = _weeklyBreakdown(allDaily, year, month);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final genresTagged = monthSeries.expand((s) => s.genres.map((g) => g.name)).toSet().length;
    final activeDaysThisMonth = allDaily.keys.where((d) => d.year == year && d.month == month).length;

    MapEntry<int, int>? peakDay;
    for (int day = 1; day <= daysInMonth; day++) {
      final c = allDaily[DateTime(year, month, day)] ?? 0;
      if (c > 0 && (peakDay == null || c > peakDay.value)) peakDay = MapEntry(day, c);
    }

    String? topGenre;
    final genreCounts = <String, int>{};
    for (final s in monthSeries) {
      for (final g in s.genres) {
        genreCounts[g.name] = (genreCounts[g.name] ?? 0) + 1;
      }
    }
    if (genreCounts.isNotEmpty) {
      topGenre = (genreCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    }

    String? topTag;
    final tagCounts = <String, int>{};
    for (final s in monthSeries) {
      for (final t in s.tags) {
        tagCounts[t.name] = (tagCounts[t.name] ?? 0) + 1;
      }
    }
    if (tagCounts.isNotEmpty) {
      topTag = (tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _miniStat('${monthSeries.length}', 'FINISHED', palette),
            const SizedBox(width: 24),
            _miniStat('$genresTagged', 'GENRES TAGGED', palette),
            const SizedBox(width: 24),
            _miniStat('$activeDaysThisMonth', 'ACTIVE DAYS', palette),
          ],
        ),
        const SizedBox(height: 20),
        Text('READING CONSISTENCY (all-time)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: palette.textSecondary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 24,
          runSpacing: 10,
          children: [
            _miniStat('${consistency.currentStreak}d', 'CURRENT STREAK', palette),
            _miniStat('${consistency.longestStreak}d', 'LONGEST STREAK', palette),
            _miniStat('${consistency.longestBreak}d', 'LONGEST BREAK', palette),
            _miniStat('${consistency.totalActiveDays}d', 'TOTAL ACTIVE DAYS', palette),
            _miniStat('${consistency.consistencyPct.toStringAsFixed(0)}%', 'CONSISTENCY', palette),
          ],
        ),
        const SizedBox(height: 20),
        Text('WEEKLY BREAKDOWN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: palette.textSecondary)),
        const SizedBox(height: 10),
        ...weeks.map((w) {
          final maxBooks = weeks.fold<int>(1, (a, e) => math.max(a, e.value));
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 90, child: Text(w.key, style: TextStyle(fontSize: 11, color: palette.textMain))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: w.value / maxBooks,
                      minHeight: 6,
                      backgroundColor: palette.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(palette.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${w.value} books', style: TextStyle(fontSize: 11, color: palette.textSecondary)),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        Text('DAILY ACTIVITY',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: palette.textSecondary)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, crossAxisSpacing: 6, mainAxisSpacing: 6,
          ),
          itemCount: daysInMonth,
          itemBuilder: (context, i) {
            final day = i + 1;
            final count = allDaily[DateTime(year, month, day)] ?? 0;
            final alpha = count == 0 ? 0.08 : (0.3 + (count.clamp(1, 4) * 0.17));
            return Container(
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text('$day', style: TextStyle(fontSize: 10,
                  color: count > 0 ? palette.onSolid : palette.textSecondary)),
            );
          },
        ),
        if (peakDay != null || topGenre != null || topTag != null) ...[
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: [
            if (peakDay != null) _highlightCard('MOST ACTIVE DAY', 'Day ${peakDay.key} (${peakDay.value} finished)', palette),
            if (topGenre != null) _highlightCard('TOP GENRE THIS MONTH', topGenre, palette),
            if (topTag != null) _highlightCard('TOP TAG THIS MONTH', topTag, palette),
          ]),
        ],
        const SizedBox(height: 20),
        if (monthSeries.isNotEmpty) _buildTopGenresCard(monthSeries, palette),
        if (monthSeries.isNotEmpty) const SizedBox(height: 20),
        if (monthSeries.isNotEmpty) _buildTopTagsCard(monthSeries, palette),
      ],
    );
  }

  Widget _miniStat(String value, String label, AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.textMain)),
        Text(label, style: TextStyle(fontSize: 10, color: palette.textSecondary)),
      ],
    );
  }

  Widget _highlightCard(String label, String value, AppPalette palette) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, letterSpacing: 0.5, color: palette.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: palette.textMain)),
        ],
      ),
    );
  }

  // 4. Top Tags

  Widget _buildTopTagsCard(List<Series> allSeries, AppPalette palette) {
    final tagCounts = <String, int>{};
    for (final s in allSeries) {
      for (final t in s.tags) {
        tagCounts[t.name] = (tagCounts[t.name] ?? 0) + 1;
      }
    }
    if (tagCounts.isEmpty) return const SizedBox.shrink();

    final sorted = tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();

    return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: palette.surfaceLight,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: palette.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TOP TAGS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                letterSpacing: 0.8, color: palette.textSecondary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: top.map((entry) => Chip(
            backgroundColor: palette.bg,
            label: Text('${entry.key} (${entry.value})',
                style: TextStyle(fontSize: 12, color: palette.textMain)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: palette.border),
            ),
          )).toList(),
        ),
      ],
    ),
    );
  }

  // 5. Radar

  Widget _buildRadarCard(List<Series> allSeries, AppPalette palette) {
    final genreCounts = <String, int>{};
    for (final s in allSeries) {
      for (final g in s.genres) {
        genreCounts[g.name] = (genreCounts[g.name] ?? 0) + 1;
      }
    }
    if (genreCounts.length < 3) return const SizedBox.shrink();

    final top = (genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))).take(6);
    final radarData = top.map((e) => RadarChartData(e.key, e.value.toDouble())).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('READING PROFILE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  letterSpacing: 0.8, color: palette.textSecondary)),
          const SizedBox(height: 12),
          Center(child: RadarChart(data: radarData)),
        ],
      ),
    );
  }

  // ─── 6. Status Distribution ────────────────────────────────────────────

  Widget _buildStatusDistributionCard(List<Series> allSeries, AppPalette palette) {
    final statusCounts = <String, int>{};
    for (final s in ReadingStatus.all) {
      statusCounts[s] = 0;
    }
    for (final s in allSeries) {
      statusCounts[s.status] = (statusCounts[s.status] ?? 0) + 1;
    }

    final total = allSeries.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STATUS BREAKDOWN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: palette.textSecondary,
                ),
              ),
              Text(
                '$total Total Works',
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...ReadingStatus.all.map((status) {
            final count = statusCounts[status] ?? 0;
            final pct = total > 0 ? (count / total) : 0.0;
            final color = ReadingStatus.colorFor(status);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.textMain,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$count (${(pct * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: palette.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 7. Rating Distribution ────────────────────────────────────────────

  Widget _buildRatingDistributionCard(List<Series> allSeries, AppPalette palette) {
    final ratingCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    int ratedTotal = 0;

    for (final s in allSeries) {
      if (s.rating != null && s.rating! >= 1 && s.rating! <= 5) {
        ratingCounts[s.rating!] = (ratingCounts[s.rating!] ?? 0) + 1;
        ratedTotal++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RATING DISTRIBUTION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ...[5, 4, 3, 2, 1].map((stars) {
            final count = ratingCounts[stars] ?? 0;
            final pct = ratedTotal > 0 ? (count / ratedTotal) : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Row(
                      children: [
                        Text('$stars', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 2),
                        Icon(Icons.star_rounded,
                            size: 14, color: palette.gold),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: palette.surfaceHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            palette.gold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 8. Format Distribution ────────────────────────────────────────────

  Widget _buildFormatDistributionCard(List<Series> allSeries, AppPalette palette) {
    final formatCounts = <String, int>{};
    for (final s in allSeries) {
      final f = s.bookType ?? 'Manga';
      formatCounts[f] = (formatCounts[f] ?? 0) + 1;
    }

    final sorted = formatCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FORMAT & BOOK TYPES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sorted.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: palette.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── 6. Top Genres ─────────────────────────────────────────────────────

  Widget _buildTopGenresCard(List<Series> allSeries, AppPalette palette) {
    final genreCounts = <String, int>{};
    for (final s in allSeries) {
      for (final g in s.genres) {
        genreCounts[g.name] = (genreCounts[g.name] ?? 0) + 1;
      }
    }

    if (genreCounts.isEmpty) return const SizedBox.shrink();

    final sorted = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOP GENRES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: top.map((entry) {
              return Chip(
                backgroundColor: palette.bg,
                label: Text(
                  '${entry.key} (${entry.value})',
                  style: TextStyle(fontSize: 12, color: palette.textMain),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: palette.border),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Plain data holder for the all-time streak / consistency block shown in
/// the timeline drilldown. Not tagged with `[stated]`-style docs since this
/// is purely derived data, no user input.
class _ConsistencyStats {
  final int currentStreak, longestStreak, longestBreak, totalActiveDays;
  final double consistencyPct;
  const _ConsistencyStats(this.currentStreak, this.longestStreak, this.longestBreak,
      this.totalActiveDays, this.consistencyPct);
}