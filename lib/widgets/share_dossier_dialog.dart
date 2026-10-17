import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/series.dart';
import '../providers/app_providers.dart';
import '../services/file_transfer.dart';
import '../theme/app_palette.dart';
import 'book_dossier_card.dart';

/// Modal dialog that presents a live preview of the classified book dossier
/// and lets the user download or share the high-resolution image card.
class ShareDossierDialog extends ConsumerStatefulWidget {
  final Series series;

  const ShareDossierDialog({super.key, required this.series});

  static Future<void> show(BuildContext context, Series series) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => ShareDossierDialog(series: series),
    );
  }

  @override
  ConsumerState<ShareDossierDialog> createState() => _ShareDossierDialogState();
}

class _ShareDossierDialogState extends ConsumerState<ShareDossierDialog> {
  final GlobalKey _cardKey = GlobalKey();
  Uint8List? _coverBytes;
  bool _isLoadingCover = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _fetchCoverBytes();
  }

  Future<void> _fetchCoverBytes() async {
    final rawPath = widget.series.coverImagePath?.trim();
    if (rawPath == null || rawPath.isEmpty) {
      if (mounted) setState(() => _isLoadingCover = false);
      return;
    }

    try {
      Uint8List? bytes;
      if (rawPath.startsWith('data:')) {
        final commaIndex = rawPath.indexOf(',');
        bytes = base64Decode(rawPath.substring(commaIndex + 1));
      } else if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
        final res = await Dio().get<List<int>>(
          rawPath,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = Uint8List.fromList(res.data ?? []);
      } else if (!kIsWeb && (rawPath.startsWith('/') || rawPath.contains(r':\'))) {
        bytes = await File(rawPath).readAsBytes();
      } else {
        // Cloudflare R2 storage key
        final r2 = ref.read(r2ServiceProvider);
        bytes = await r2.downloadBytes(rawPath);
      }

      if (mounted) {
        setState(() {
          _coverBytes = bytes;
          _isLoadingCover = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCover = false);
    }
  }

  Future<void> _downloadImage(AppPalette palette) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      // Small pause to ensure repaint boundary has settled
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Render boundary unavailable');

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');

      final pngBytes = byteData.buffer.asUint8List();
      final cleanTitle = widget.series.title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final filename = 'dossier_${cleanTitle.isEmpty ? widget.series.id : cleanTitle}.png';

      await saveBinaryFile(filename, pngBytes, mimeType: 'image/png');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb ? 'Downloaded $filename' : 'Image saved & ready to share!'),
            backgroundColor: palette.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate image: $e'),
            backgroundColor: palette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _copyTextSummary(AppPalette palette) async {
    final s = widget.series;
    final lines = <String>[
      s.author != null && s.author!.trim().isNotEmpty
          ? '${s.title} by ${s.author!.trim()}'
          : s.title,
      [
        s.status,
        if (s.rating != null && s.rating! > 0) '${s.rating}/5',
        if (s.yearPublished != null && s.yearPublished!.isNotEmpty) s.yearPublished!,
        if (s.standaloneChapterCount != null && s.standaloneChapterCount! > 0)
          '${s.standaloneChapterCount} chapters',
      ].join(' · '),
      if (s.genres.isNotEmpty) s.genres.map((g) => g.name).join(', '),
      if (s.synopsis != null && s.synopsis!.trim().isNotEmpty) '\n${s.synopsis!.trim()}',
    ];
    final text = lines.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Book summary copied to clipboard!'),
          backgroundColor: palette.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final screen = MediaQuery.of(context).size;

    // Dimensions: card is 420 x 560
    final maxPreviewHeight = (screen.height * 0.65).clamp(320.0, 560.0);
    final previewScale = maxPreviewHeight / 560.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.share_rounded, size: 18, color: palette.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Share Classified Dossier',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: palette.textMain,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: palette.textSecondary,
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Preview Canvas
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _isLoadingCover
                    ? const SizedBox(
                        height: 260,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Preparing classified dossier…'),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 420 * previewScale,
                            height: 560 * previewScale,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: RepaintBoundary(
                                key: _cardKey,
                                child: BookDossierCard(
                                  series: widget.series,
                                  coverBytes: _coverBytes,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),

              const Divider(height: 1),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Copy Text button
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: palette.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onPressed: () => _copyTextSummary(palette),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Text'),
                    ),
                    const Spacer(),
                    // Download Image button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isExporting || _isLoadingCover
                          ? null
                          : () => _downloadImage(palette),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(_isExporting ? 'Generating…' : 'Download Image'),
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
