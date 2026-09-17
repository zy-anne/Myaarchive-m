import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../theme/colors.dart';
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

  Future<void> _handleDelete(Series series) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceLight,
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final dataLayer = ref.read(dataLayerProvider);
        await dataLayer.seriesDelete(series.id);
        ref.invalidate(seriesListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${series.title}"'),
              backgroundColor: AppColors.primary,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _quickUpdateDate(Series series, {bool isStarted = false, bool isFinished = false}) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFinished ? 'Marked as finished today' : 'Marked as started today'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    String toLaunch = url.trim();
    if (!toLaunch.startsWith('http://') && !toLaunch.startsWith('https://')) {
      toLaunch = 'https://$toLaunch';
    }
    final uri = Uri.tryParse(toLaunch);
    if (uri != null) {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildTabHeader(String label, [int? count]) {
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
                color: AppColors.darkSurfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkTextMuted,
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
            backgroundColor: AppColors.darkBackground,
            appBar: AppBar(backgroundColor: AppColors.darkSurface),
            body: const Center(child: Text('Title not found')),
          );
        }

        final isStandalone = series.kind == 'standalone';
        final filesTotalCount = linksList.length + attachmentsList.length;

        return Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 320.0,
                  pinned: true,
                  backgroundColor: AppColors.darkSurface,
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
                      onPressed: () => _handleDelete(series),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildHeaderBackground(series),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.darkSurface,
                        border: Border(
                          bottom: BorderSide(color: AppColors.darkBorder, width: 1),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: AppColors.primaryLight,
                        indicatorWeight: 2.5,
                        labelColor: AppColors.primaryLight,
                        unselectedLabelColor: AppColors.darkTextMuted,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                        tabs: [
                          _buildTabHeader('Details'),
                          _buildTabHeader(
                            isStandalone ? 'Thoughts' : 'Volumes',
                            isStandalone ? null : volumesList.length,
                          ),
                          _buildTabHeader('Characters', charactersList.length),
                          _buildTabHeader('Gallery', galleryList.length),
                          _buildTabHeader('Files', filesTotalCount),
                          _buildTabHeader('Glossary', glossaryList.length),
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
                _buildDetailsTab(series),
                _buildVolumesOrThoughtsTab(series, volumesList),
                _buildCharactersTab(series, charactersList),
                _buildGalleryTab(series, galleryList),
                _buildFilesTab(series, linksList, attachmentsList),
                _buildGlossaryTab(series, glossaryList),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.darkBackground,
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHeaderBackground(Series series) {
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
                Colors.black.withOpacity(0.6),
                AppColors.darkBackground.withOpacity(0.95),
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
                      color: Colors.black.withOpacity(0.5),
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
                            color: AppColors.darkSurfaceLighter,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            series.kind == 'series' ? 'Series' : 'Standalone',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.darkTextMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (series.isNsfw) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.9),
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
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                        height: 1.2,
                      ),
                    ),
                    if (series.author != null && series.author!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'By ${series.author!}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.darkTextMuted,
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
                              onTap: () => _quickUpdateDate(series, isStarted: true),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: const Text(
                                  '+ Started Today',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primaryLight,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (series.dateStarted == null && series.dateFinished == null)
                            const SizedBox(width: 6),
                          if (series.dateFinished == null)
                            InkWell(
                              onTap: () => _quickUpdateDate(series, isFinished: true),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                                ),
                                child: const Text(
                                  '+ Finished Today',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.success,
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

  Widget _buildDetailsTab(Series series) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Content Warnings
        if (series.contentWarnings.isNotEmpty) ...[
          const Text(
            'CONTENT WARNINGS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.error,
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
          const Text(
            'GENRES & TAGS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
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
          const Text(
            'SYNOPSIS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            series.synopsis!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Metadata grid
        const Text(
          'DETAILS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: AppColors.darkTextMuted,
          ),
        ),
        const SizedBox(height: 10),
        _buildDetailsGrid(series),

        // Overall Thoughts for series (standalone thoughts appear in Tab 2)
        if (series.kind != 'standalone' &&
            series.overallThoughts != null &&
            series.overallThoughts!.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'OVERALL THOUGHTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Text(
              series.overallThoughts!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.darkText,
              ),
            ),
          ),
        ],

        // Chapter Thoughts for series
        if (series.kind != 'standalone' &&
            series.chapterThoughts != null &&
            series.chapterThoughts!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'CHAPTER THOUGHTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Text(
              series.chapterThoughts!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.darkText,
              ),
            ),
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDetailsGrid(Series series) {
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
      return const Text(
        'No additional details provided.',
        style: TextStyle(color: AppColors.darkTextMuted, fontSize: 13),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
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
                  style: const TextStyle(
                    color: AppColors.darkTextMuted,
                    fontSize: 13,
                  ),
                ),
                Flexible(
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.darkText,
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

  Widget _buildVolumesOrThoughtsTab(Series series, List<Volume> volumes) {
    if (series.kind == 'standalone') {
      return _buildStandaloneThoughtsView(series);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddVolumeDialog(series.id),
        child: const Icon(Icons.add),
      ),
      body: volumes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.book_rounded, size: 44, color: AppColors.darkTextMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'No volumes logged yet',
                    style: TextStyle(color: AppColors.darkTextMuted),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddVolumeDialog(series.id),
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
                  color: AppColors.darkSurfaceLight,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.darkBorder),
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
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'V${v.volumeNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryLight,
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.darkText,
                                ),
                              ),
                              if (v.chapterRange != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Chapters: ${v.chapterRange}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.darkTextMuted,
                                  ),
                                ),
                              ],
                              if (v.dateRead != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Read on: ${v.dateRead}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.darkTextMuted,
                                  ),
                                ),
                              ],
                              if (v.thoughts != null && v.thoughts!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  v.thoughts!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.darkText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: AppColors.darkTextMuted,
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

  Widget _buildStandaloneThoughtsView(Series series) {
    final hasThoughts = (series.overallThoughts != null && series.overallThoughts!.isNotEmpty) ||
        (series.chapterThoughts != null && series.chapterThoughts!.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'STANDALONE THOUGHTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.darkTextMuted,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showEditThoughtsDialog(series),
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
              color: AppColors.darkSurfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 40, color: AppColors.darkTextMuted),
                  const SizedBox(height: 8),
                  const Text(
                    'No thoughts added yet',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Add your overall thoughts and chapter notes for this book.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _showEditThoughtsDialog(series),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
                color: AppColors.darkSurfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overall Thoughts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    series.overallThoughts!,
                    style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.darkText),
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
                color: AppColors.darkSurfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chapter Notes / Timeline',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    series.chapterThoughts!,
                    style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.darkText),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  void _showEditThoughtsDialog(Series series) {
    final overallCtrl = TextEditingController(text: series.overallThoughts ?? '');
    final chapterCtrl = TextEditingController(text: series.chapterThoughts ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceLight,
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
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddVolumeDialog(int seriesId) {
    final numberCtrl = TextEditingController(text: '1');
    final titleCtrl = TextEditingController();
    final chaptersCtrl = TextEditingController();
    final thoughtsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceLight,
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
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─── Tab 3: Characters ─────────────────────────────────────────────────────

  Widget _buildCharactersTab(Series series, List<Character> characters) {
    final relationshipsAsync = ref.watch(seriesRelationshipsProvider(series.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddCharacterDialog(series.id),
        child: const Icon(Icons.person_add_rounded),
      ),
      body: characters.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline_rounded, size: 44, color: AppColors.darkTextMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'No characters added yet',
                    style: TextStyle(color: AppColors.darkTextMuted),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddCharacterDialog(series.id),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Character'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                ...characters.map((c) => _buildCharacterCard(c, series.id)),

                // Relationships Section
                relationshipsAsync.when(
                  data: (rels) {
                    if (rels.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'CHARACTER RELATIONSHIPS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.darkTextMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...rels.map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.darkSurfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.darkBorder),
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
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  r.label ?? r.type,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primaryLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.darkTextMuted),
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

  Widget _buildCharacterCard(Character c, int seriesId) {
    return Card(
      color: AppColors.darkSurfaceLight,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showCharacterDetailSheet(c, seriesId),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceLighter,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: c.profileImagePath != null
                    ? CoverImage(
                        imagePath: c.profileImagePath,
                        borderRadius: BorderRadius.circular(25),
                        fit: BoxFit.cover,
                      )
                    : const Center(
                        child: Icon(Icons.person, color: AppColors.primaryLight),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            c.role,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryLight,
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
                        style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                      ),
                    ],
                    if (c.personality != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Personality: ${c.personality!}',
                        style: const TextStyle(fontSize: 12, color: AppColors.darkText),
                      ),
                    ],
                    if (c.notes != null && c.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        c.notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.darkTextMuted,
                onPressed: () async {
                  await ref.read(dataLayerProvider).charactersDelete(c.id);
                  ref.invalidate(seriesCharactersProvider(seriesId));
                  ref.invalidate(seriesRelationshipsProvider(seriesId));
                },
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.darkTextMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Character Detail Sheet ─────────────────────────────────────────────

  void _showCharacterDetailSheet(Character c, int seriesId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurfaceLight,
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
                        color: AppColors.darkBorder,
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
                          color: AppColors.darkSurfaceLighter,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: c.profileImagePath != null
                            ? CoverImage(
                                imagePath: c.profileImagePath,
                                borderRadius: BorderRadius.circular(32),
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: Icon(Icons.person,
                                    color: AppColors.primaryLight, size: 30),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
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
                                    color: AppColors.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.role,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (c.statusRole != null && c.statusRole!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.darkSurfaceLighter,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      c.statusRole!,
                                      style: const TextStyle(
                                          fontSize: 11, color: AppColors.darkTextMuted),
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
                  if (c.age != null && c.age!.isNotEmpty) _detailRow('Age', c.age!),
                  if (c.lifeStatus != null && c.lifeStatus!.isNotEmpty)
                    _detailRow('Life Status', c.lifeStatus!),
                  if (c.volumeAppearances != null && c.volumeAppearances!.isNotEmpty)
                    _detailRow('Appears In', c.volumeAppearances!),
                  if (c.personality != null && c.personality!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _detailSection('Personality', c.personality!),
                  ],
                  if (c.overallVibes != null && c.overallVibes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _detailSection('Overall Vibes', c.overallVibes!),
                  ],
                  if (c.appearsText != null && c.appearsText!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _detailSection('How They Appear', c.appearsText!),
                  ],
                  if (c.realityText != null && c.realityText!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _detailSection('Reality Behind It', c.realityText!),
                  ],
                  if (c.notes != null && c.notes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _detailSection('Notes / Bio', c.notes!),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAddCharacterDialog(seriesId, existingCharacter: c);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryLight,
                            side: const BorderSide(color: AppColors.darkBorder),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(dataLayerProvider).charactersDelete(c.id);
                            ref.invalidate(seriesCharactersProvider(seriesId));
                            ref.invalidate(seriesRelationshipsProvider(seriesId));
                            if (mounted) Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.delete_outline,
                              size: 16, color: AppColors.error),
                          label: const Text('Delete',
                              style: TextStyle(color: AppColors.error)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.darkBorder),
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.darkTextMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppColors.darkText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: AppColors.darkTextMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.darkBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.darkText),
          ),
        ),
      ],
    );
  }

  void _showAddCharacterDialog(int seriesId, {Character? existingCharacter}) {
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
        backgroundColor: AppColors.darkSurfaceLight,
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
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─── Tab 4: Gallery ────────────────────────────────────────────────────────

  Widget _buildGalleryTab(Series series, List<GalleryImage> images) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddGalleryDialog(series.id),
        child: const Icon(Icons.add_photo_alternate_rounded),
      ),
      body: images.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_library_outlined, size: 44, color: AppColors.darkTextMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'No gallery pictures yet',
                    style: TextStyle(color: AppColors.darkTextMuted),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddGalleryDialog(series.id),
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
                  onTap: () => _showGalleryImageDetail(img, series.id),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: AppColors.darkSurfaceLight,
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
                                color: Colors.black.withOpacity(0.65),
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

  void _showGalleryImageDetail(GalleryImage img, int seriesId) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.darkSurfaceLight,
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
                  style: const TextStyle(fontSize: 13, color: AppColors.darkText),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    onPressed: () async {
                      await ref.read(dataLayerProvider).galleryDelete(img.id);
                      ref.invalidate(seriesGalleryProvider(seriesId));
                      if (mounted) Navigator.pop(ctx);
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

  void _showAddGalleryDialog(int seriesId) {
    final pathCtrl = TextEditingController();
    final captionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceLight,
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
              final img = GalleryImage(
                id: 0,
                seriesId: seriesId,
                imagePath: pathCtrl.text.trim(),
                caption: captionCtrl.text.isEmpty ? null : captionCtrl.text,
              );
              await ref.read(dataLayerProvider).galleryAdd(img);
              ref.invalidate(seriesGalleryProvider(seriesId));
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ─── Tab 5: Files (Links & Attachments) ─────────────────────────────────────

  Widget _buildFilesTab(Series series, List<LinkAttachment> links, List<Attachment> attachments) {
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
                    color: AppColors.darkTextMuted,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showAddLinkDialog(series.id),
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('+ Link'),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showAddFileDialog(series.id),
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
                color: AppColors.darkSurfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.folder_open_rounded, size: 40, color: AppColors.darkTextMuted),
                    const SizedBox(height: 8),
                    const Text(
                      'No files or links yet',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Attach PDFs, external bookmarks, notes, or reading resources.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // External Links Section
            if (links.isNotEmpty) ...[
              const Text(
                'EXTERNAL LINKS & BOOKMARKS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(height: 8),
              ...links.map((l) => _buildLinkTile(l, series.id)),
              const SizedBox(height: 20),
            ],

            // Attachments Section
            if (attachments.isNotEmpty) ...[
              const Text(
                'FILE ATTACHMENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(height: 8),
              ...attachments.map((f) => _buildAttachmentTile(f, series.id)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLinkTile(LinkAttachment l, int seriesId) {
    String displayLabel = l.label ?? '';
    if (displayLabel.isEmpty) {
      final uri = Uri.tryParse(l.url);
      displayLabel = uri?.host.replaceAll('www.', '') ?? l.url;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.link_rounded, size: 20, color: AppColors.primaryLight),
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
                  style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            color: AppColors.primaryLight,
            tooltip: 'Open',
            onPressed: () => _launchExternalUrl(l.url),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.darkTextMuted,
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

  Widget _buildAttachmentTile(Attachment f, int seriesId) {
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
        color: AppColors.darkSurfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceLighter,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insert_drive_file_rounded, size: 20, color: AppColors.primaryLight),
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
                    style: const TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            color: AppColors.primaryLight,
            tooltip: 'Open',
            onPressed: () => _launchExternalUrl(f.filePath),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.darkTextMuted,
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

  void _showAddLinkDialog(int seriesId) {
    final urlCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceLight,
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
              final link = LinkAttachment(
                id: 0,
                seriesId: seriesId,
                url: urlCtrl.text.trim(),
                label: labelCtrl.text.isEmpty ? null : labelCtrl.text.trim(),
              );
              await ref.read(dataLayerProvider).linksAdd(link);
              ref.invalidate(seriesLinksProvider(seriesId));
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Add Link'),
          ),
        ],
      ),
    );
  }

  void _showAddFileDialog(int seriesId) {
    final nameCtrl = TextEditingController();
    final pathCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceLight,
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
              final attachment = Attachment(
                id: 0,
                seriesId: seriesId,
                filePath: pathCtrl.text.trim(),
                fileName: nameCtrl.text.trim(),
              );
              await ref.read(dataLayerProvider).attachmentsAdd(attachment);
              ref.invalidate(seriesAttachmentsProvider(seriesId));
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Add File'),
          ),
        ],
      ),
    );
  }

  // ─── Tab 6: Glossary ───────────────────────────────────────────────────────

  Widget _buildGlossaryTab(Series series, List<GlossaryTerm> terms) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddOrEditGlossaryTermDialog(series.id),
        child: const Icon(Icons.add),
      ),
      body: terms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book_rounded, size: 44, color: AppColors.darkTextMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'No glossary terms yet',
                    style: TextStyle(color: AppColors.darkTextMuted),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Track in-world jargon, honorifics, or lore terms specific to this title.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.darkTextMuted),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddOrEditGlossaryTermDialog(series.id),
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
                  color: AppColors.darkSurfaceLight,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.darkBorder),
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
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  color: AppColors.darkTextMuted,
                                  onPressed: () => _showAddOrEditGlossaryTermDialog(series.id, existingTerm: t),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  color: AppColors.darkTextMuted,
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
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.darkText,
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

  void _showAddOrEditGlossaryTermDialog(int seriesId, {GlossaryTerm? existingTerm}) {
    final termCtrl = TextEditingController(text: existingTerm?.term ?? '');
    final defCtrl = TextEditingController(text: existingTerm?.definition ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceLight,
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
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}