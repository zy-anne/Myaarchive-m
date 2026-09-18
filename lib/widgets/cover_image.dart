import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/app_providers.dart';
import '../theme/colors.dart';

/// Cover image widget supporting local files, remote URLs, and Cloudflare R2 keys.
class CoverImage extends ConsumerWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  const CoverImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.auto_stories_rounded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = borderRadius ?? BorderRadius.circular(8);

    if (imagePath == null || imagePath!.trim().isEmpty) {
      return _buildPlaceholder(context, radius);
    }

    final path = imagePath!.trim();

    // Check if it's a local file path
    if (path.startsWith('/') || path.contains(r':\')) {
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: radius,
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildPlaceholder(context, radius),
          ),
        );
      }
    }

    // Check if it's already an HTTP(S) URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: path,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) => _buildShimmer(context, radius),
          errorWidget: (context, url, error) =>
              _buildPlaceholder(context, radius),
        ),
      );
    }

    // Otherwise, it's an R2 key: resolve presigned download URL
    final r2 = ref.watch(r2ServiceProvider);
    return FutureBuilder<String>(
      future: r2.getDownloadUrl(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmer(context, radius);
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          debugPrint('CoverImage: failed to resolve R2 url for key "$path": ${snapshot.error}');
          return _buildPlaceholder(context, radius);
        }
        debugPrint('CoverImage: resolved "$path" -> ${snapshot.data}');
        return ClipRRect(
          borderRadius: radius,
          child: CachedNetworkImage(
            imageUrl: snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            placeholder: (context, url) => _buildShimmer(context, radius),
            errorWidget: (context, url, error) {
              debugPrint('CoverImage: CachedNetworkImage failed for $url: $error');
              return _buildPlaceholder(context, radius);
            },
          ),
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context, BorderRadius radius) {
    return Shimmer.fromColors(
      baseColor: AppColors.darkSurfaceLight,
      highlightColor: AppColors.darkSurfaceLighter,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceLight,
          borderRadius: radius,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, BorderRadius radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceLight,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.darkBorder.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: (width != null && width! < 60) ? 20 : 36,
          color: AppColors.darkTextMuted.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
