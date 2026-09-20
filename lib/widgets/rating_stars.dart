import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Rating stars widget for display or interactive user rating.
class RatingStars extends StatelessWidget {
  final int? rating;
  final int maxRating;
  final double size;
  final ValueChanged<int>? onRatingChanged;

  const RatingStars({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 14,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final current = rating ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final starIndex = index + 1;
        final isFilled = current >= starIndex;

        final icon = Icon(
          isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: isFilled ? palette.gold : palette.textSecondary.withValues(alpha: 0.4),
        );

        if (onRatingChanged != null) {
          return GestureDetector(
            onTap: () {
              if (current == starIndex) {
                onRatingChanged!(0); // Toggle off if clicked again
              } else {
                onRatingChanged!(starIndex);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              child: icon,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(right: 1.0),
          child: icon,
        );
      }),
    );
  }
}