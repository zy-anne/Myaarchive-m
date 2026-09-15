import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/metadata.dart';
import '../../models/series.dart';
import '../../providers/app_providers.dart';
import '../../theme/colors.dart';
import '../../widgets/radar_chart.dart';

/// Reading Statistics screen mirroring the web app's comprehensive analytics view.
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _selectedYear = DateTime.now().year;

  void _showSetGoalDialog(String? currentGoal) {
    final controller = TextEditingController(text: currentGoal ?? '25');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceLight,
        title: Text('Annual Reading Goal ($_selectedYear)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set target number of books/manga to complete this year:',
              style: TextStyle(color: AppColors.darkTextMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                color: AppColors.darkText,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              decoration: InputDecoration(
                labelText: 'Target Works',
                suffixText: 'books',
                filled: true,
                fillColor: AppColors.darkBackground,
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                final user = ref.read(authStateProvider).value;
                if (user != null) {
                  await ref
                      .read(dataLayerProvider)
                      .settingsSet(user.id, 'annualReadingGoal', val.toString());
                  ref.invalidate(appSettingsProvider);
                }
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Goal'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(allSeriesForStatsProvider);
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text(
          'Reading Statistics',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
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
                        color: AppColors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        size: 36,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Reading Data Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add titles to your library to track reading milestones, velocity, and genres.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.darkTextMuted, fontSize: 13),
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
            color: AppColors.primaryLight,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _buildMilestoneHero(seriesList, goal),
                const SizedBox(height: 16),
                _buildQuickStatsGrid(seriesList),
                const SizedBox(height: 20),
                _buildReadingTimelineCard(seriesList),   // new
                const SizedBox(height: 20),
                _buildStatusDistributionCard(seriesList),
                const SizedBox(height: 20),
                _buildRatingDistributionCard(seriesList),
                const SizedBox(height: 20),
                _buildFormatDistributionCard(seriesList),
                const SizedBox(height: 20),
                _buildTopGenresCard(seriesList),
                const SizedBox(height: 20),
                _buildTopTagsCard(seriesList),           // new
                const SizedBox(height: 20),
                _buildRadarCard(seriesList),             // new
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
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

  // ─── 1. Annual Milestone Hero ──────────────────────────────────────────

  Widget _buildMilestoneHero(List<Series> allSeries, int? goal) {
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
          colors: [
            AppColors.primary.withOpacity(0.35),
            AppColors.darkSurfaceLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  const Text(
                    'ANNUAL MILESTONE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_selectedYear Reading Journey',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppColors.primaryLight,
                tooltip: 'Set Reading Goal',
                onPressed: () => _showSetGoalDialog(goal?.toString()),
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
                const Text(
                  'of',
                  style: TextStyle(color: AppColors.darkTextMuted, fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  '$goal',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'works read',
                  style: TextStyle(color: AppColors.darkTextMuted, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pctText%',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
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
                backgroundColor: AppColors.darkSurfaceLighter,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Remaining text
            Text(
              remaining > 0
                  ? '$remaining more to reach your annual goal!'
                  : '🎉 Congratulations! You reached your reading goal!',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.darkTextMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            // Goal unset prompt
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBackground.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined,
                      color: AppColors.gold, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No annual goal set yet for this year.',
                      style: TextStyle(fontSize: 13, color: AppColors.darkText),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showSetGoalDialog(null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
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

  Widget _buildQuickStatsGrid(List<Series> allSeries) {
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
            AppColors.primaryLight, Icons.menu_book_rounded),
        _buildStatCard('Queued', '$planningCount', 'In Planning',
            AppColors.softCream, Icons.schedule_rounded),
        _buildStatCard('Finished', '$completedCount', 'Completed',
            const Color(0xFF7FC9A0), Icons.check_circle_outline_rounded),
        _buildStatCard('Avg Rating', avgRating, '$ratedCount rated titles',
            AppColors.gold, Icons.star_rounded),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String subtitle,
    Color accentColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.darkBorder.withOpacity(0.8),
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
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: AppColors.darkTextMuted,
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
              color: AppColors.darkTextMuted.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Reading Timeline (monthly bar chart)

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

  Widget _buildReadingTimelineCard(List<Series> allSeries) {
    final counts = _monthlyFinishedCounts(allSeries, _selectedYear);
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('READING TIMELINE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      letterSpacing: 0.8, color: AppColors.darkTextMuted)),
              DropdownButton<int>(
                value: _selectedYear,
                dropdownColor: AppColors.darkSurfaceLight,
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: AppColors.primaryLight,
                    fontSize: 12, fontWeight: FontWeight.w600),
                items: _availableYears(allSeries)
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (y) { if (y != null) setState(() => _selectedYear = y); },
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
                return Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 14,
                        child: count > 0
                            ? Center(
                                child: Text('$count',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                        color: isPeak ? AppColors.primaryLight : AppColors.darkTextMuted)))
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
                                    ? AppColors.primaryLight
                                    : AppColors.primary.withValues(alpha: count > 0 ? 0.55 : 0.12),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(months[i], style: const TextStyle(fontSize: 9, color: AppColors.darkTextMuted)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Top Tags

  Widget _buildTopTagsCard(List<Series> allSeries) {
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
      color: AppColors.darkSurfaceLight,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TOP TAGS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                letterSpacing: 0.8, color: AppColors.darkTextMuted)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: top.map((entry) => Chip(
            backgroundColor: AppColors.darkBackground,
            label: Text('${entry.key} (${entry.value})',
                style: const TextStyle(fontSize: 12, color: AppColors.darkText)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.darkBorder),
            ),
          )).toList(),
        ),
      ],
    ),
    );
  }

  // 5. Radar

  Widget _buildRadarCard(List<Series> allSeries) {
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
        color: AppColors.darkSurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('READING PROFILE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  letterSpacing: 0.8, color: AppColors.darkTextMuted)),
          const SizedBox(height: 12),
          Center(child: RadarChart(data: radarData)),
        ],
      ),
    );
  }

  // ─── 6. Status Distribution ────────────────────────────────────────────

  Widget _buildStatusDistributionCard(List<Series> allSeries) {
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
        color: AppColors.darkSurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'STATUS BREAKDOWN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.darkTextMuted,
                ),
              ),
              Text(
                '$total Total Works',
                style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
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
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$count (${(pct * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.darkTextMuted,
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
                      backgroundColor: AppColors.darkSurfaceLighter,
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

  Widget _buildRatingDistributionCard(List<Series> allSeries) {
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
        color: AppColors.darkSurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RATING DISTRIBUTION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
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
                        const Icon(Icons.star_rounded,
                            size: 14, color: AppColors.gold),
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
                        backgroundColor: AppColors.darkSurfaceLighter,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.gold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.darkTextMuted,
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

  Widget _buildFormatDistributionCard(List<Series> allSeries) {
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
        color: AppColors.darkSurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FORMAT & BOOK TYPES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
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
                  color: AppColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
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

  Widget _buildTopGenresCard(List<Series> allSeries) {
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
        color: AppColors.darkSurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP GENRES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: top.map((entry) {
              return Chip(
                backgroundColor: AppColors.darkBackground,
                label: Text(
                  '${entry.key} (${entry.value})',
                  style: const TextStyle(fontSize: 12, color: AppColors.darkText),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppColors.darkBorder),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
