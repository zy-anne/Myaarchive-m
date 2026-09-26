import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/attachment.dart';
import '../../models/character.dart';
import '../../models/gallery_image.dart';
import '../../models/glossary_term.dart';
import '../../models/link_attachment.dart';
import '../../models/metadata.dart';
import '../../models/series.dart';
import '../../models/volume.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_palette.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tag_chip.dart';

/// Series detail screen matching the desktop and web app with 6 dedicated tabs:
/// 1. Details
/// 2. Volumes (or Thoughts if standalone)
/// 3. Characters
/// 4. Gallery
/// 5. Files (Attachments + External Links)
/// 6. Glossary
class SeriesDetailScreen extends ConsumerStatefulWidget {
  final int seriesId;

  const SeriesDetailScreen({super.key, required this.seriesId});

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete(Series series, AppPalette palette) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: const Text('Delete Title?'),
        content: Text(
          'Are you sure you want to delete "${series.title}"? All associated volumes, characters, gallery images, attachments, and glossary terms will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      try {
        final dataLayer = ref.read(dataLayerProvider);
        await dataLayer.seriesDelete(series.id);
        ref.invalidate(seriesListProvider);
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Deleted "${series.title}"'),
              backgroundColor: palette.primary,
            ),
          );
          router.pop();
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: palette.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _quickUpdateDate(Series series, AppPalette palette, {bool isStarted = false, bool isFinished = false}) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final now = DateTime.now();
    final today =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final updated = series.copyWith(
      dateStarted: isStarted ? today : series.dateStarted,
      dateFinished: isFinished ? today : series.dateFinished,
      status: isFinished
          ? ReadingStatus.finished
          : (isStarted ? ReadingStatus.reading : series.status),
    );

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dataLayerProvider).seriesUpdate(
            user.id,
            updated,
            tagNames: series.tags.map((t) => t.name).toList(),
            genreNames: series.genres.map((g) => g.name).toList(),
            warningNames: series.contentWarnings.map((w) => w.name).toList(),
          );
      ref.invalidate(seriesDetailProvider(widget.seriesId));
      ref.invalidate(seriesListProvider);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(isFinished ? 'Marked as finished today' : 'Marked as started today'),
            backgroundColor: palette.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: palette.danger,
          ),
        );
      }
    }
  }

  Future<void> _launchExternalUrl(String url, AppPalette palette) async {
    String toLaunch = url.trim();
    if (!toLaunch.startsWith('http://') && !toLaunch.startsWith('https://')) {
      toLaunch = 'https://$toLaunch';
    }
    final uri = Uri.tryParse(toLaunch);
    if (uri != null) {
      final messenger = ScaffoldMessenger.of(context);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            backgroundColor: palette.danger,
          ),
        );
      }
    }
  }

  Widget _buildTabHeader(String label, AppPalette palette, [int? count]) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: palette.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final seriesAsync = ref.watch(seriesDetailProvider(widget.seriesId));

    // Watch list providers to display dynamic counts on tabs
    final volumesList = ref.watch(seriesVolumesProvider(widget.seriesId)).valueOrNull ?? [];
    final charactersList = ref.watch(seriesCharactersProvider(widget.seriesId)).valueOrNull ?? [];
    final galleryList = ref.watch(seriesGalleryProvider(widget.seriesId)).valueOrNull ?? [];
    final linksList = ref.watch(seriesLinksProvider(widget.seriesId)).valueOrNull ?? [];
    final attachmentsList = ref.watch(seriesAttachmentsProvider(widget.seriesId)).valueOrNull ?? [];
    final glossaryList = ref.watch(seriesGlossaryProvider(widget.seriesId)).valueOrNull ?? [];

    return seriesAsync.when(
      data: (series) {
        if (series == null) {
          return Scaffold(
            backgroundColor: palette.bg,
            appBar: AppBar(backgroundColor: palette.surface),
            body: const Center(child: Text('Title not found')),
          );
        }

        final isStandalone = series.kind == 'standalone';
        final filesTotalCount = linksList.length + attachmentsList.length;

        return Scaffold(
          backgroundColor: palette.bg,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 320.0,
                  pinned: true,
                  backgroundColor: palette.surface,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Library',
                    onPressed: () => context.pop(),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit Title',
                      onPressed: () => context.push('/series/edit/${series.id}'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Delete',
                      onPressed: () => _handleDelete(series, palette),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildHeaderBackground(series, palette),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.surface,
                        border: Border(
                          bottom: BorderSide(color: palette.border, width: 1),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: palette.accent,
                        indicatorWeight: 2.5,
                        labelColor: palette.accent,
                        unselectedLabelColor: palette.textSecondary,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                        tabs: [
                          _buildTabHeader('Details', palette),
                          _buildTabHeader(
                            isStandalone ? 'Thoughts' : 'Volumes',
                            palette,
                            isStandalone ? null : volumesList.length,
                          ),
                          _buildTabHeader('Characters', palette, charactersList.length),
                          _buildTabHeader('Gallery', palette, galleryList.length),
                          _buildTabHeader('Files', palette, filesTotalCount),
                          _buildTabHeader('Glossary', palette, glossaryList.length),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(series, palette),
                _buildVolumesOrThoughtsTab(series, volumesList, palette),
                _buildCharactersTab(series, charactersList, palette),
                _buildGalleryTab(series, galleryList, palette),
                _buildFilesTab(series, linksList, attachmentsList, palette),
                _buildGlossaryTab(series, glossaryList, palette),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: palette.bg,
        body: Center(
          child: CircularProgressIndicator(color: palette.accent),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: palette.bg,
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHeaderBackground(Series series, AppPalette palette) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred backdrop of cover image
        if (series.coverImagePath != null)
          Opacity(
            opacity: 0.25,
            child: CoverImage(
              imagePath: series.coverImagePath,
              fit: BoxFit.cover,
            ),
          ),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                palette.bg.withValues(alpha: 0.95),
              ],
            ),
          ),
        ),

        // Hero Cover and Series Info
        Positioned(
          left: 16,
          right: 16,
          bottom: 58,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Cover Thumbnail
              Container(
                width: 95,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CoverImage(
                  imagePath: series.coverImagePath,
                  borderRadius: BorderRadius.circular(10),
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),

              // Title, Author, Status, Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        StatusBadge(status: series.status),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.surfaceHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            series.kind == 'series' ? 'Series' : 'Standalone',
                            style: TextStyle(
                              fontSize: 10,
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (series.isNsfw) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: palette.danger.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '18+',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      series.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      // FIX: was TextStyle(fontFamily: 'Outfit', ...) — the raw
                      // font family string never resolved (no bundled asset
                      // font named "Outfit" declared in pubspec.yaml), so it
                      // silently fell back to the platform default and looked
                      // mismatched against everything else using
                      // GoogleFonts.outfit(...). Switched to the real loader.
                      style: GoogleFonts.outfit(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: palette.textMain,
                        height: 1.2,
                      ),
                    ),
                    if (series.author != null && series.author!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'By ${series.author!}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                    if (series.rating != null && series.rating! > 0) ...[
                      const SizedBox(height: 6),
                      RatingStars(rating: series.rating, size: 14),
                    ],
                    // Quick Start / Finish actions
                    if (series.dateStarted == null || series.dateFinished == null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (series.dateStarted == null)
                            InkWell(
                              onTap: () => _quickUpdateDate(series, palette, isStarted: true),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: palette.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '+ Started Today',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: palette.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (series.dateStarted == null && series.dateFinished == null)
                            const SizedBox(width: 6),
                          if (series.dateFinished == null)
                            InkWell(
                              onTap: () => _quickUpdateDate(series, palette, isFinished: true),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: palette.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: palette.success.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '+ Finished Today',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: palette.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Tab 1: Details ────────────────────────────────────────────────────────

  Widget _buildDetailsTab(Series series, AppPalette palette) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Content Warnings
        if (series.contentWarnings.isNotEmpty) ...[
          Text(
            'CONTENT WARNINGS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.danger,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: series.contentWarnings
                .map((cw) => TagChip.fromWarning(cw))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Genres & Tags
        if (series.genres.isNotEmpty || series.tags.isNotEmpty) ...[
          Text(
            'GENRES & TAGS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...series.genres.map((g) => TagChip.fromGenre(g)),
              ...series.tags.map((t) => TagChip.fromTag(t)),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Synopsis
        if (series.synopsis != null && series.synopsis!.isNotEmpty) ...[
          Text(
            'SYNOPSIS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            series.synopsis!,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: palette.textMain,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Metadata grid
        Text(
          'DETAILS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        _buildDetailsGrid(series, palette),

        // Overall Thoughts for series (standalone thoughts appear in Tab 2)
        if (series.kind != 'standalone' &&
            series.overallThoughts != null &&
            series.overallThoughts!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'OVERALL THOUGHTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              series.overallThoughts!,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: palette.textMain,
              ),
            ),
          ),
        ],

        // Chapter Thoughts for series
        if (series.kind != 'standalone' &&
            series.chapterThoughts != null &&
            series.chapterThoughts!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'CHAPTER THOUGHTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              series.chapterThoughts!,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: palette.textMain,
              ),
            ),
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDetailsGrid(Series series, AppPalette palette) {
    final items = <MapEntry<String, String>>[];

    if (series.bookType != null) items.add(MapEntry('Format', series.bookType!));
    if (series.artist != null) items.add(MapEntry('Artist', series.artist!));
    if (series.fandom != null) items.add(MapEntry('Fandom', series.fandom!));
    if (series.originalLanguage != null) {
      items.add(MapEntry('Original Lang', series.originalLanguage!));
    }
    if (series.countryOfOrigin != null) {
      items.add(MapEntry('Country', series.countryOfOrigin!));
    }
    items.add(MapEntry('Language Read', series.languageRead));
    if (series.yearPublished != null) {
      items.add(MapEntry('Year', series.yearPublished!));
    }
    if (series.dateStarted != null) {
      items.add(MapEntry('Started', series.dateStarted!));
    }
    if (series.dateFinished != null) {
      items.add(MapEntry('Finished', series.dateFinished!));
    }
    if (series.originalPublisher != null) {
      items.add(MapEntry('Publisher', series.originalPublisher!));
    }
    if (series.englishPublisher != null) {
      items.add(MapEntry('Eng Publisher', series.englishPublisher!));
    }
    if (series.completelyTranslated != null) {
      items.add(MapEntry('Completed TL', series.completelyTranslated!));
    }
    if (series.statusCountryOfOrigin != null) {
      items.add(MapEntry('Status (Origin)', series.statusCountryOfOrigin!));
    }
    if (series.licensedEnglish != null) {
      items.add(MapEntry('Licensed (EN)', series.licensedEnglish!));
    }
    if (series.kind == 'standalone' && series.standaloneChapterCount != null) {
      items.add(MapEntry('Chapters', '${series.standaloneChapterCount}'));
    }

    if (items.isEmpty) {
      return Text(
        'No additional details provided.',
        style: TextStyle(color: palette.textSecondary, fontSize: 13),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: items.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.key,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Flexible(
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: palette.textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Tab 2: Volumes / Thoughts ─────────────────────────────────────────────

  Widget _buildVolumesOrThoughtsTab(Series series, List<Volume> volumes, AppPalette palette) {
    if (series.kind == 'standalone') {
      return _buildStandaloneThoughtsView(series, palette);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddVolumeDialog(series.id, palette),
        child: const Icon(Icons.add),
      ),
      body: volumes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_rounded, size: 44, color: palette.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'No volumes logged yet',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddVolumeDialog(series.id, palette),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Volume 1'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: volumes.length,
              itemBuilder: (context, index) {
                final v = volumes[index];
                return Card(
                  color: palette.surfaceLight,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: palette.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'V${v.volumeNumber}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: palette.accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.title ?? 'Volume ${v.volumeNumber}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: palette.textMain,
                                ),
                              ),
                              if (v.chapterRange != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Chapters: ${v.chapterRange}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                              if (v.dateRead != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Read on: ${v.dateRead}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                              if (v.thoughts != null && v.thoughts!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  v.thoughts!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: palette.textMain,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: palette.textSecondary,
                          onPressed: () async {
                            await ref.read(dataLayerProvider).volumesDelete(v.id);
                            ref.invalidate(seriesVolumesProvider(series.id));
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStandaloneThoughtsView(Series series, AppPalette palette) {
    final hasThoughts = (series.overallThoughts != null && series.overallThoughts!.isNotEmpty) ||
        (series.chapterThoughts != null && series.chapterThoughts!.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STANDALONE THOUGHTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: palette.textSecondary,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showEditThoughtsDialog(series, palette),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: Text(hasThoughts ? 'Edit Thoughts' : 'Add Thoughts'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!hasThoughts)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: palette.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.edit_note_rounded, size: 40, color: palette.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                    'No thoughts added yet',
                    style: TextStyle(fontWeight: FontWeight.bold, color: palette.textMain),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your overall thoughts and chapter notes for this book.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: palette.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _showEditThoughtsDialog(series, palette),
                    // NOTE: this button used to render its "Add Thoughts"
                    // label invisibly — ElevatedButton defaults label color
                    // to colorScheme.primary when only backgroundColor is
                    // set, and here they're the same color. Fixed at the
                    // theme level in AppTheme (elevatedButtonTheme now
                    // defaults foregroundColor to palette.onSolid), so no
                    // change is needed here as long as that theme fix is
                    // applied. Left explicit for clarity/robustness:
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onSolid,
                    ),
                    child: const Text('Add Thoughts'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          if (series.overallThoughts != null && series.overallThoughts!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Thoughts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    series.overallThoughts!,
                    style: TextStyle(fontSize: 13, height: 1.5, color: palette.textMain),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (series.chapterThoughts != null && series.chapterThoughts!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chapter Notes / Timeline',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    series.chapterThoughts!,
                    style: TextStyle(fontSize: 13, height: 1.5, color: palette.textMain),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  void _showEditThoughtsDialog(Series series, AppPalette palette) {
    final overallCtrl = TextEditingController(text: series.overallThoughts ?? '');
    final chapterCtrl = TextEditingController(text: series.chapterThoughts ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: const Text('Edit Thoughts'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: overallCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Overall Thoughts',
                  hintText: 'What did you think of the book as a whole?',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: chapterCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Chapter Notes / Timeline',
                  hintText: 'Ch 1: Great opening...\nCh 5: Plot twist!',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = ref.read(authStateProvider).value;
              if (user == null) return;
              final navigator = Navigator.of(ctx);
              final updated = series.copyWith(
                overallThoughts: overallCtrl.text.trim().isEmpty ? null : overallCtrl.text.trim(),
                chapterThoughts: chapterCtrl.text.trim().isEmpty ? null : chapterCtrl.text.trim(),
              );
              await ref.read(dataLayerProvider).seriesUpdate(
                    user.id,
                    updated,
                    tagNames: series.tags.map((t) => t.name).toList(),
                    genreNames: series.genres.map((g) => g.name).toList(),
                    warningNames: series.contentWarnings.map((w) => w.name).toList(),
                  );
              ref.invalidate(seriesDetailProvider(widget.seriesId));
              if (mounted) navigator.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddVolumeDialog(int seriesId, AppPalette palette) {
    final numberCtrl = TextEditingController(text: '1');
    final titleCtrl = TextEditingController();
    final chaptersCtrl = TextEditingController();
    final thoughtsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: const Text('Add Volume'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Volume Number'),
              ),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Volume Title (Optional)'),
              ),
              TextField(
                controller: chaptersCtrl,
                decoration: const InputDecoration(labelText: 'Chapter Range (e.g. 1-8)'),
              ),
              TextField(
                controller: thoughtsCtrl,
                decoration: const InputDecoration(labelText: 'Volume Thoughts'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final volNum = int.tryParse(numberCtrl.text) ?? 1;
              final navigator = Navigator.of(ctx);
              final newVol = Volume(
                id: 0,
                seriesId: seriesId,
                volumeNumber: volNum,
                title: titleCtrl.text.isEmpty ? null : titleCtrl.text,
                chapterRange: chaptersCtrl.text.isEmpty ? null : chaptersCtrl.text,
                thoughts: thoughtsCtrl.text.isEmpty ? null : thoughtsCtrl.text,
              );
              await ref.read(dataLayerProvider).volumesCreate(newVol);
              ref.invalidate(seriesVolumesProvider(seriesId));
              if (mounted) navigator.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─── Tab 3: Characters ─────────────────────────────────────────────────────

  Widget _buildCharactersTab(Series series, List<Character> characters, AppPalette palette) {
    final relationshipsAsync = ref.watch(seriesRelationshipsProvider(series.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddCharacterDialog(series.id, palette),
        child: const Icon(Icons.person_add_rounded),
      ),
      body: characters.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 44, color: palette.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'No characters added yet',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddCharacterDialog(series.id, palette),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Character'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                ...characters.map((c) => _buildCharacterCard(c, series.id, palette)),

                // Relationships Section
                relationshipsAsync.when(
                  data: (rels) {
                    if (rels.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'CHARACTER RELATIONSHIPS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...rels.map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: palette.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: palette.border),
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Text(
                                r.fromCharacterName ?? 'Char #${r.fromCharacterId}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: palette.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  r.label ?? r.type,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_rounded, size: 14, color: palette.textSecondary),
                              Text(
                                r.toCharacterName ?? 'Char #${r.toCharacterId}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
    );
  }

  Widget _buildCharacterCard(Character c, int seriesId, AppPalette palette) {
    return Card(
      color: palette.surfaceLight,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showCharacterDetailSheet(c, seriesId, palette),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: palette.surfaceHigh,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: c.profileImagePath != null
                    ? CoverImage(
                        imagePath: c.profileImagePath,
                        borderRadius: BorderRadius.circular(25),
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Icon(Icons.person, color: palette.accent),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: palette.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            c.role,
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (c.statusRole != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        c.statusRole!,
                        style: TextStyle(fontSize: 12, color: palette.textSecondary),
                      ),
                    ],
                    if (c.personality != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Personality: ${c.personality!}',
                        style: TextStyle(fontSize: 12, color: palette.textMain),
                      ),
                    ],
                    if (c.notes != null && c.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        c.notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: palette.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: palette.textSecondary,
                onPressed: () async {
                  await ref.read(dataLayerProvider).charactersDelete(c.id);
                  ref.invalidate(seriesCharactersProvider(seriesId));
                  ref.invalidate(seriesRelationshipsProvider(seriesId));
                },
              ),
              Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Icon(Icons.chevron_right_rounded, size: 18, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Character Detail Sheet ─────────────────────────────────────────────

  void _showCharacterDetailSheet(Character c, int seriesId, AppPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surfaceLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: palette.surfaceHigh,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: c.profileImagePath != null
                            ? CoverImage(
                                imagePath: c.profileImagePath,
                                borderRadius: BorderRadius.circular(32),
                                fit: BoxFit.cover,
                              )
                            : Center(
                                child: Icon(Icons.person,
                                    color: palette.accent, size: 30),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              // FIX: was TextStyle(fontFamily: 'Outfit', ...)
                              // — same unresolved-font-family issue as the
                              // series title above. Switched to the real
                              // Google Fonts loader.
                              style: GoogleFonts.outfit(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: palette.textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: palette.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.role,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: palette.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (c.statusRole != null && c.statusRole!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: palette.surfaceHigh,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      c.statusRole!,
                                      style: TextStyle(
                                          fontSize: 11, color: palette.textSecondary),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (c.age != null && c.age!.isNotEmpty) _detailRow('Age', c.age!, palette),
                  if (c.lifeStatus != null && c.lifeStatus!.isNotEmpty)
                    _detailRow('Life Status', c.lifeStatus!, palette),
                  if (c.volumeAppearances != null && c.volumeAppearances!.isNotEmpty)
                    _detailRow('Appears In', c.volumeAppearances!, palette),
                  if (c.personality != null && c.personality!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _detailSection('Personality', c.personality!, palette),
                  ],
                  if (c.overallVibes != null && c.overallVibes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _detailSection('Overall Vibes', c.overallVibes!, palette),
                  ],
                  if (c.appearsText != null && c.appearsText!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _detailSection('How They Appear', c.appearsText!, palette),
                  ],
                  if (c.realityText != null && c.realityText!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _detailSection('Reality Behind It', c.realityText!, palette),
                  ],
                  if (c.notes != null && c.notes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _detailSection('Notes / Bio', c.notes!, palette),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAddCharacterDialog(seriesId, palette, existingCharacter: c);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.accent,
                            side: BorderSide(color: palette.border),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final navigator = Navigator.of(ctx);
                            await ref.read(dataLayerProvider).charactersDelete(c.id);
                            ref.invalidate(seriesCharactersProvider(seriesId));
                            ref.invalidate(seriesRelationshipsProvider(seriesId));
                            if (mounted) navigator.pop();
                          },
                          icon: Icon(Icons.delete_outline,
                              size: 16, color: palette.danger),
                          label: Text('Delete',
                              style: TextStyle(color: palette.danger)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: palette.border),
                          ),
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

  Widget _detailRow(String label, String value, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: palette.textMain),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(String title, String value, AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 13, height: 1.4, color: palette.textMain),
          ),
        ),
      ],
    );
  }

  void _showAddCharacterDialog(int seriesId, AppPalette palette, {Character? existingCharacter}) {
    final nameCtrl = TextEditingController(text: existingCharacter?.name ?? '');
    final roleCtrl = TextEditingController(text: existingCharacter?.role ?? 'Protagonist');
    final statusRoleCtrl = TextEditingController(text: existingCharacter?.statusRole ?? '');
    final ageCtrl = TextEditingController(text: existingCharacter?.age ?? '');
    final lifeStatusCtrl = TextEditingController(text: existingCharacter?.lifeStatus ?? '');
    final volumeAppearancesCtrl =
        TextEditingController(text: existingCharacter?.volumeAppearances ?? '');
    final personalityCtrl = TextEditingController(text: existingCharacter?.personality ?? '');
    final overallVibesCtrl = TextEditingController(text: existingCharacter?.overallVibes ?? '');
    final appearsTextCtrl = TextEditingController(text: existingCharacter?.appearsText ?? '');
    final realityTextCtrl = TextEditingController(text: existingCharacter?.realityText ?? '');
    final notesCtrl = TextEditingController(text: existingCharacter?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: Text(existingCharacter == null ? 'Add Character' : 'Edit Character'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Character Name'),
                ),
                TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Role (e.g. Protagonist, Antagonist, Side)'),
                ),
                TextField(
                  controller: statusRoleCtrl,
                  decoration: const InputDecoration(labelText: 'Status / Title (Optional)'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageCtrl,
                        decoration: const InputDecoration(labelText: 'Age'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: lifeStatusCtrl,
                        decoration: const InputDecoration(labelText: 'Life Status'),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: volumeAppearancesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Appears In (Volumes/Chapters)'),
                ),
                TextField(
                  controller: personalityCtrl,
                  decoration: const InputDecoration(labelText: 'Personality Traits'),
                ),
                TextField(
                  controller: overallVibesCtrl,
                  decoration: const InputDecoration(labelText: 'Overall Vibes'),
                  maxLines: 2,
                ),
                TextField(
                  controller: appearsTextCtrl,
                  decoration: const InputDecoration(labelText: 'How They Appear'),
                  maxLines: 2,
                ),
                TextField(
                  controller: realityTextCtrl,
                  decoration: const InputDecoration(labelText: 'Reality Behind It'),
                  maxLines: 2,
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes / Bio'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final navigator = Navigator.of(ctx);
              String? orNull(String s) => s.trim().isEmpty ? null : s.trim();

              if (existingCharacter == null) {
                final newChar = Character(
                  id: 0,
                  seriesId: seriesId,
                  name: nameCtrl.text.trim(),
                  role: roleCtrl.text.trim(),
                  statusRole: orNull(statusRoleCtrl.text),
                  age: orNull(ageCtrl.text),
                  lifeStatus: orNull(lifeStatusCtrl.text),
                  volumeAppearances: orNull(volumeAppearancesCtrl.text),
                  personality: orNull(personalityCtrl.text),
                  overallVibes: orNull(overallVibesCtrl.text),
                  appearsText: orNull(appearsTextCtrl.text),
                  realityText: orNull(realityTextCtrl.text),
                  notes: orNull(notesCtrl.text),
                );
                await ref.read(dataLayerProvider).charactersCreate(newChar);
              } else {
                final updated = existingCharacter.copyWith(
                  name: nameCtrl.text.trim(),
                  role: roleCtrl.text.trim(),
                  statusRole: orNull(statusRoleCtrl.text),
                  age: orNull(ageCtrl.text),
                  lifeStatus: orNull(lifeStatusCtrl.text),
                  volumeAppearances: orNull(volumeAppearancesCtrl.text),
                  personality: orNull(personalityCtrl.text),
                  overallVibes: orNull(overallVibesCtrl.text),
                  appearsText: orNull(appearsTextCtrl.text),
                  realityText: orNull(realityTextCtrl.text),
                  notes: orNull(notesCtrl.text),
                );
                await ref.read(dataLayerProvider).charactersUpdate(updated);
              }
              ref.invalidate(seriesCharactersProvider(seriesId));
              if (mounted) navigator.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─── Tab 4: Gallery ────────────────────────────────────────────────────────

  Widget _buildGalleryTab(Series series, List<GalleryImage> images, AppPalette palette) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddGalleryDialog(series.id, palette),
        child: const Icon(Icons.add_photo_alternate_rounded),
      ),
      body: images.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 44, color: palette.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'No gallery pictures yet',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddGalleryDialog(series.id, palette),
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: const Text('Add Picture'),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final img = images[index];
                return GestureDetector(
                  onTap: () => _showGalleryImageDetail(img, series.id, palette),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: palette.surfaceLight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CoverImage(imagePath: img.imagePath, fit: BoxFit.cover),
                          if (img.caption != null && img.caption!.isNotEmpty)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                color: Colors.black.withValues(alpha: 0.65),
                                child: Text(
                                  img.caption!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showGalleryImageDetail(GalleryImage img, int seriesId, AppPalette palette) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: palette.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 260,
                child: CoverImage(imagePath: img.imagePath, fit: BoxFit.contain),
              ),
            ),
            if (img.caption != null && img.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  img.caption!,
                  style: TextStyle(fontSize: 13, color: palette.textMain),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: palette.danger),
                    onPressed: () async {
                      final navigator = Navigator.of(ctx);
                      await ref.read(dataLayerProvider).galleryDelete(img.id);
                      ref.invalidate(seriesGalleryProvider(seriesId));
                      if (mounted) navigator.pop();
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGalleryDialog(int seriesId, AppPalette palette) {
    final pathCtrl = TextEditingController();
    final captionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: const Text('Add Gallery Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pathCtrl,
              decoration: const InputDecoration(
                labelText: 'Image URL or R2 Key',
                hintText: 'https://... or gallery/...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: captionCtrl,
              decoration: const InputDecoration(labelText: 'Caption (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pathCtrl.text.trim().isEmpty) return;
              final navigator = Navigator.of(ctx);
              final img = GalleryImage(
                id: 0,
                seriesId: seriesId,
                imagePath: pathCtrl.text.trim(),
                caption: captionCtrl.text.isEmpty ? null : captionCtrl.text,
              );
              await ref.read(dataLayerProvider).galleryAdd(img);
              ref.invalidate(seriesGalleryProvider(seriesId));
              if (mounted) navigator.pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ─── Tab 5: Files (Links & Attachments) ─────────────────────────────────────

  Widget _buildFilesTab(Series series, List<LinkAttachment> links, List<Attachment> attachments, AppPalette palette) {
    final isEmpty = links.isEmpty && attachments.isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // Toolbar row
          Row(
            children: [
              Expanded(
                child: Text(
                  'ATTACHED RESOURCES',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showAddLinkDialog(series.id, palette),
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('+ Link'),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showAddFileDialog(series.id, palette),
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('+ File'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: palette.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open_rounded, size: 40, color: palette.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      'No files or links yet',
                      style: TextStyle(fontWeight: FontWeight.bold, color: palette.textMain),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Attach PDFs, external bookmarks, notes, or reading resources.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // External Links Section
            if (links.isNotEmpty) ...[
              Text(
                'EXTERNAL LINKS & BOOKMARKS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: palette.accent,
                ),
              ),
              const SizedBox(height: 8),
              ...links.map((l) => _buildLinkTile(l, series.id, palette)),
              const SizedBox(height: 20),
            ],

            // Attachments Section
            if (attachments.isNotEmpty) ...[
              Text(
                'FILE ATTACHMENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: palette.accent,
                ),
              ),
              const SizedBox(height: 8),
              ...attachments.map((f) => _buildAttachmentTile(f, series.id, palette)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLinkTile(LinkAttachment l, int seriesId, AppPalette palette) {
    String displayLabel = l.label ?? '';
    if (displayLabel.isEmpty) {
      final uri = Uri.tryParse(l.url);
      displayLabel = uri?.host.replaceAll('www.', '') ?? l.url;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.link_rounded, size: 20, color: palette.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  l.url,
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            color: palette.accent,
            tooltip: 'Open',
            onPressed: () => _launchExternalUrl(l.url, palette),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: palette.textSecondary,
            tooltip: 'Delete',
            onPressed: () async {
              await ref.read(dataLayerProvider).linksDelete(l.id);
              ref.invalidate(seriesLinksProvider(seriesId));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentTile(Attachment f, int seriesId, AppPalette palette) {
    String formattedSize = '';
    if (f.fileSize != null) {
      if (f.fileSize! < 1024) {
        formattedSize = '${f.fileSize} B';
      } else if (f.fileSize! < 1024 * 1024) {
        formattedSize = '${(f.fileSize! / 1024).toStringAsFixed(1)} KB';
      } else {
        formattedSize = '${(f.fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.insert_drive_file_rounded, size: 20, color: palette.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (formattedSize.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    formattedSize,
                    style: TextStyle(fontSize: 12, color: palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            color: palette.accent,
            tooltip: 'Open',
            onPressed: () => _launchExternalUrl(f.filePath, palette),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: palette.textSecondary,
            tooltip: 'Delete',
            onPressed: () async {
              await ref.read(dataLayerProvider).attachmentsDelete(f.id);
              ref.invalidate(seriesAttachmentsProvider(seriesId));
            },
          ),
        ],
      ),
    );
  }

  void _showAddLinkDialog(int seriesId, AppPalette palette) {
    final urlCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: const Text('Add Link Attachment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(labelText: 'URL (https://...)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Label (e.g. Official Site, MyAnimeList)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (urlCtrl.text.trim().isEmpty) return;
              final navigator = Navigator.of(ctx);
              final link = LinkAttachment(
                id: 0,
                seriesId: seriesId,
                url: urlCtrl.text.trim(),
                label: labelCtrl.text.isEmpty ? null : labelCtrl.text.trim(),
              );
              await ref.read(dataLayerProvider).linksAdd(link);
              ref.invalidate(seriesLinksProvider(seriesId));
              if (mounted) navigator.pop();
            },
            child: const Text('Add Link'),
          ),
        ],
      ),
    );
  }

  void _showAddFileDialog(int seriesId, AppPalette palette) {
    final nameCtrl = TextEditingController();
    final pathCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: const Text('Add File Attachment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'File Name (e.g. Map.pdf)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pathCtrl,
              decoration: const InputDecoration(
                labelText: 'File URL or Storage Key',
                hintText: 'https://... or files/...',
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
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || pathCtrl.text.trim().isEmpty) return;
              final navigator = Navigator.of(ctx);
              final attachment = Attachment(
                id: 0,
                seriesId: seriesId,
                filePath: pathCtrl.text.trim(),
                fileName: nameCtrl.text.trim(),
              );
              await ref.read(dataLayerProvider).attachmentsAdd(attachment);
              ref.invalidate(seriesAttachmentsProvider(seriesId));
              if (mounted) navigator.pop();
            },
            child: const Text('Add File'),
          ),
        ],
      ),
    );
  }

  // ─── Tab 6: Glossary ───────────────────────────────────────────────────────

  Widget _buildGlossaryTab(Series series, List<GlossaryTerm> terms, AppPalette palette) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddOrEditGlossaryTermDialog(series.id, palette),
        child: const Icon(Icons.add),
      ),
      body: terms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_rounded, size: 44, color: palette.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'No glossary terms yet',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track in-world jargon, honorifics, or lore terms specific to this title.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: palette.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddOrEditGlossaryTermDialog(series.id, palette),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Term'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: terms.length,
              itemBuilder: (context, index) {
                final t = terms[index];
                return Card(
                  color: palette.surfaceLight,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: palette.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              t.term,
                              // FIX: same unresolved-fontFamily bug as the
                              // two spots above — switched to the real
                              // Google Fonts loader.
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: palette.accent,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  color: palette.textSecondary,
                                  onPressed: () => _showAddOrEditGlossaryTermDialog(series.id, palette, existingTerm: t),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  color: palette.textSecondary,
                                  onPressed: () async {
                                    await ref.read(dataLayerProvider).glossaryDelete(t.id);
                                    ref.invalidate(seriesGlossaryProvider(series.id));
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (t.definition != null && t.definition!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            t.definition!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: palette.textMain,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddOrEditGlossaryTermDialog(int seriesId, AppPalette palette, {GlossaryTerm? existingTerm}) {
    final termCtrl = TextEditingController(text: existingTerm?.term ?? '');
    final defCtrl = TextEditingController(text: existingTerm?.definition ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceLight,
        title: Text(existingTerm == null ? 'Add Glossary Term' : 'Edit Glossary Term'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: termCtrl,
              decoration: const InputDecoration(labelText: 'Term / Lore Concept'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: defCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Definition / Meaning'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (termCtrl.text.trim().isEmpty) return;
              final navigator = Navigator.of(ctx);
              if (existingTerm == null) {
                final newTerm = GlossaryTerm(
                  id: 0,
                  seriesId: seriesId,
                  term: termCtrl.text.trim(),
                  definition: defCtrl.text.trim().isEmpty ? null : defCtrl.text.trim(),
                );
                await ref.read(dataLayerProvider).glossaryAdd(newTerm);
              } else {
                final updated = existingTerm.copyWith(
                  term: termCtrl.text.trim(),
                  definition: defCtrl.text.trim().isEmpty ? null : defCtrl.text.trim(),
                );
                await ref.read(dataLayerProvider).glossaryUpdate(updated);
              }
              ref.invalidate(seriesGlossaryProvider(seriesId));
              if (mounted) navigator.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}