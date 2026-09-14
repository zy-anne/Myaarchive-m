import 'package:flutter/material.dart';
import '../models/metadata.dart';
import '../models/series.dart';
import '../theme/colors.dart';
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
    return isGrid ? _buildGridCard(context) : _buildListCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    final statusColor = ReadingStatus.colorFor(series.status);
    final String bookType = series.bookType ?? 'Manga';
    final String kindLabel = series.kind == 'series' ? 'Series' : 'Standalone';

    // Chapter or volume count label
    String? countLabel;
    if (series.standaloneChapterCount != null &&
        series.standaloneChapterCount! > 0) {
      countLabel = '${series.standaloneChapterCount} Chs';
    } else if (series.volumeCount > 0) {
      countLabel = '${series.volumeCount} Vols';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141926), // Deep midnight card from wireframe
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF232B40),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top: Status Badge & Chapter Count ────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2338),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        series.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (countLabel != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2338),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2B3650)),
                    ),
                    child: Text(
                      countLabel,
                      style: const TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Center: Cover Image or Book Icon (Wireframe) ────────────
            Expanded(
              child: Center(
                child: series.coverImagePath != null &&
                        series.coverImagePath!.trim().isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: AspectRatio(
                          aspectRatio: 0.72,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CoverImage(
                              imagePath: series.coverImagePath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.menu_book_rounded,
                        size: 46,
                        color: AppColors.darkTextMuted.withValues(alpha: 0.35),
                      ),
              ),
            ),

            // ── Bottom: Badges row, Title, Author, Rating ────────────────
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2438),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2C3852)),
                  ),
                  child: Text(
                    bookType,
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2438),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2C3852)),
                  ),
                  child: Text(
                    kindLabel,
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Title (Bold white)
            Text(
              series.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),

            // Author (Muted)
            Text(
              series.author ?? 'Unknown Author',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.darkTextMuted.withValues(alpha: 0.75),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),

            // Rating Stars
            RatingStars(
              rating: series.rating ?? 0,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141926),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF232B40),
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
                            style: const TextStyle(
                              color: AppColors.darkText,
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
                        style: const TextStyle(
                          color: AppColors.darkTextMuted,
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
                            style: const TextStyle(
                              color: AppColors.darkTextMuted,
                              fontSize: 11,
                            ),
                          ),
                        if (series.volumeCount > 0 &&
                            series.standaloneChapterCount != null)
                          const Text(
                            ' • ',
                            style: TextStyle(
                              color: AppColors.darkTextMuted,
                              fontSize: 11,
                            ),
                          ),
                        if (series.standaloneChapterCount != null)
                          Text(
                            '${series.standaloneChapterCount} chs',
                            style: const TextStyle(
                              color: AppColors.darkTextMuted,
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
