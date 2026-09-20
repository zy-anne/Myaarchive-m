import 'package:flutter/material.dart';
import '../models/metadata.dart';
import '../models/series.dart';
import '../theme/app_palette.dart';
import 'cover_image.dart';
import 'rating_stars.dart';
import 'status_badge.dart';

/// Series card widget with Grid matching the wireframe and List display modes.
class SeriesCard extends StatelessWidget {
  final Series series;
  final VoidCallback onTap;
  final bool isGrid;

  const SeriesCard({
    super.key,
    required this.series,
    required this.onTap,
    this.isGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return isGrid ? _buildGridCard(context, palette) : _buildListCard(context, palette);
  }

  Widget _buildGridCard(BuildContext context, AppPalette palette) {
  final statusColor = ReadingStatus.colorFor(series.status);
  final String formatLabel = (series.bookType ?? 'Manga').toUpperCase();
  final isDark = Theme.of(context).brightness == Brightness.dark;

  // Chapter or volume count label
  String? countLabel;
  if (series.standaloneChapterCount != null &&
      series.standaloneChapterCount! > 0) {
    countLabel = '${series.standaloneChapterCount} CH';
  } else if (series.volumeCount > 0) {
    countLabel = '${series.volumeCount} VOL';
  }

  return GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Full-bleed cover with overlay tag badges ─────────────
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                series.coverImagePath != null &&
                        series.coverImagePath!.trim().isNotEmpty
                    ? CoverImage(
                        imagePath: series.coverImagePath,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.zero,
                      )
                    : Container(
                        color: palette.surfaceLight,
                        child: Center(
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 42,
                            color:
                                palette.textSecondary.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: _buildOverlayTag(
                    formatLabel,
                    Colors.black.withValues(alpha: 0.62),
                    Colors.white,
                  ),
                ),
                if (series.isNsfw)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _buildOverlayTag(
                      'NSFW',
                      palette.danger,
                      Colors.white,
                    ),
                  ),
              ],
            ),
          ),

          // ── Title / author / status row ───────────────────────────
          // This block sits on `palette.surface`, which is light in Light
          // Mode and dark in Dark Mode — so every color here must come
          // from the palette (never a hardcoded Colors.white / fixed hex)
          // or it goes unreadable / stays the wrong hue when the mode flips.
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textMain,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  series.author ?? 'Unknown Author',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        series.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (countLabel != null)
                      Text(
                        countLabel,
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildOverlayTag(String text, Color bg, Color fg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: fg,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
  );
}

  Widget _buildListCard(BuildContext context, AppPalette palette) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.border,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Thumbnail
              SizedBox(
                width: 65,
                height: 95,
                child: CoverImage(
                  imagePath: series.coverImagePath,
                  borderRadius: BorderRadius.circular(8),
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),

              // Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            series.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textMain,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        StatusBadge(status: series.status, compact: true),
                      ],
                    ),
                    if (series.author != null && series.author!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        series.author!,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),

                    // Rating & Volume / Chapter stats
                    Row(
                      children: [
                        if (series.rating != null && series.rating! > 0) ...[
                          RatingStars(rating: series.rating, size: 12),
                          const SizedBox(width: 8),
                        ],
                        if (series.volumeCount > 0)
                          Text(
                            '${series.volumeCount} vols',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        if (series.volumeCount > 0 &&
                            series.standaloneChapterCount != null)
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        if (series.standaloneChapterCount != null)
                          Text(
                            '${series.standaloneChapterCount} chs',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}