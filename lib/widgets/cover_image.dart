import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/app_providers.dart';
import '../theme/app_palette.dart';

/// Cover image widget supporting local files, remote URLs, Cloudflare R2
/// keys, and (web only) `blob:`/`data:` URIs from a just-picked image that
/// hasn't finished uploading yet.
class CoverImage extends ConsumerStatefulWidget {
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
  ConsumerState<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends ConsumerState<CoverImage> {
  Future<String>? _downloadUrlFuture;
  String? _resolvedPath;

  @override
  void initState() {
    super.initState();
    _initFutureIfNeeded();
  }

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _initFutureIfNeeded();
    }
  }

  void _initFutureIfNeeded() {
    final rawPath = widget.imagePath?.trim();
    if (rawPath == null || rawPath.isEmpty) {
      _downloadUrlFuture = null;
      _resolvedPath = null;
      return;
    }

    final isSpecial = rawPath.startsWith('blob:') ||
        rawPath.startsWith('data:') ||
        rawPath.startsWith('http://') ||
        rawPath.startsWith('https://') ||
        (!kIsWeb && (rawPath.startsWith('/') || rawPath.contains(r':\')));

    if (!isSpecial) {
      _resolvedPath = rawPath;
      _downloadUrlFuture = ref.read(r2ServiceProvider).getDownloadUrl(rawPath);
    } else {
      _downloadUrlFuture = null;
      _resolvedPath = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(8);
    final palette = context.palette;

    if (widget.imagePath == null || widget.imagePath!.trim().isEmpty) {
      return _buildPlaceholder(context, radius, palette);
    }

    final path = widget.imagePath!.trim();

    // Web-only: a picked-but-not-yet-uploaded image.
    if (kIsWeb && path.startsWith('blob:')) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          path,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, __, ___) =>
              _buildPlaceholder(context, radius, palette),
        ),
      );
    }

    // A data: URI (base64-inlined image)
    if (path.startsWith('data:')) {
      try {
        final commaIndex = path.indexOf(',');
        final bytes = base64Decode(path.substring(commaIndex + 1));
        return ClipRRect(
          borderRadius: radius,
          child: Image.memory(
            bytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (_, __, ___) =>
                _buildPlaceholder(context, radius, palette),
          ),
        );
      } catch (_) {
        return _buildPlaceholder(context, radius, palette);
      }
    }

    // Local file path
    if (!kIsWeb && (path.startsWith('/') || path.contains(r':\'))) {
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: radius,
          child: Image.file(
            file,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (_, __, ___) =>
                _buildPlaceholder(context, radius, palette),
          ),
        );
      }
    }

    // Direct HTTP(S) URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: path,
          cacheKey: path,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholder: (context, url) =>
              _buildShimmer(context, radius, palette),
          errorWidget: (context, url, error) =>
              _buildPlaceholder(context, radius, palette),
        ),
      );
    }

    // Cloudflare R2 key
    if (_downloadUrlFuture == null || _resolvedPath != path) {
      _resolvedPath = path;
      _downloadUrlFuture = ref.read(r2ServiceProvider).getDownloadUrl(path);
    }

    return FutureBuilder<String>(
      future: _downloadUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmer(context, radius, palette);
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          debugPrint(
              'CoverImage: failed to resolve R2 url for key "$path": ${snapshot.error}');
          return _buildPlaceholder(context, radius, palette);
        }
        return ClipRRect(
          borderRadius: radius,
          child: CachedNetworkImage(
            imageUrl: snapshot.data!,
            cacheKey: path,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            placeholder: (context, url) =>
                _buildShimmer(context, radius, palette),
            errorWidget: (context, url, error) {
              debugPrint(
                  'CoverImage: CachedNetworkImage failed for $url: $error');
              return _buildPlaceholder(context, radius, palette);
            },
          ),
        );
      },
    );
  }

  Widget _buildShimmer(
      BuildContext context, BorderRadius radius, AppPalette palette) {
    return Shimmer.fromColors(
      baseColor: palette.surfaceLight,
      highlightColor: palette.surfaceHigh,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: palette.surfaceLight,
          borderRadius: radius,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
      BuildContext context, BorderRadius radius, AppPalette palette) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: radius,
        border: Border.all(
          color: palette.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          widget.fallbackIcon,
          size: (widget.width != null && widget.width! < 60) ? 20 : 36,
          color: palette.textSecondary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}