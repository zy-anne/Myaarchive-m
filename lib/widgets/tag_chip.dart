import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/metadata.dart';
import '../theme/colors.dart';

/// Tag / Genre chip with deterministic colors and optional delete callback.
class TagChip extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isWarning;

  const TagChip({
    super.key,
    required this.label,
    this.color,
    this.onDeleted,
    this.onTap,
    this.isSelected = false,
    this.isWarning = false,
  });

  factory TagChip.fromTag(Tag tag, {VoidCallback? onDeleted, VoidCallback? onTap}) {
    return TagChip(
      label: tag.name,
      color: tag.parsedColor,
      onDeleted: onDeleted,
      onTap: onTap,
    );
  }

  factory TagChip.fromGenre(Genre genre, {VoidCallback? onDeleted, VoidCallback? onTap}) {
    return TagChip(
      label: genre.name,
      color: genre.parsedColor,
      onDeleted: onDeleted,
      onTap: onTap,
    );
  }

  factory TagChip.fromWarning(ContentWarning warning, {VoidCallback? onDeleted}) {
    return TagChip(
      label: warning.name,
      color: AppColors.error,
      onDeleted: onDeleted,
      isWarning: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = isWarning
        ? AppColors.error
        : (color ?? AppColors.primary);

    final bgOpacity = isSelected ? 0.35 : 0.15;
    final borderOpacity = isSelected ? 0.8 : 0.3;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.only(
          left: 10,
          right: onDeleted != null ? 4 : 10,
          top: 4,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: bgOpacity),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: chipColor.withValues(alpha: borderOpacity),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isWarning) ...[
              Icon(Icons.warning_amber_rounded, size: 12, color: chipColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: chipColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onDeleted,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: chipColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
