import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/series.dart';

/// Renders a classified dossier notebook page inspired by secret archive dossiers:
/// - Dark charcoal/olive desk background
/// - Open loose-leaf ring binder page with hole punches and left binder staples
/// - Typewriter "FILE: 1234" stamp
/// - Tilted Polaroid photo of the book cover with paperclip (omitted when there is no cover)
/// - Classified book specs table (Title, Author, Release, Chapters, Genre, Synopsis)
/// - Only the file number and the @username footer are blacked out; everything else is readable
/// - Card height grows with the content so the full synopsis always shows
class BookDossierCard extends StatelessWidget {
  final Series series;
  final Uint8List? coverBytes;
  final double scale;

  const BookDossierCard({
    super.key,
    required this.series,
    this.coverBytes,
    this.scale = 1.0,
  });

  static const Color deskColor = Color(0xFF383A33);
  static const Color paperColor = Color(0xFFF7F4EB);
  static const Color inkColor = Color(0xFF2E2F29);
  static const Color inkMuted = Color(0xFF6B685F);
  static const Color redactionColor = Color(0xFF141414);

  @override
  Widget build(BuildContext context) {
    const cardWidth = 420.0;

    final fileNumber = (series.id % 9000 + 1000).toString();
    final releaseYear = series.yearPublished != null && series.yearPublished!.trim().isNotEmpty
        ? series.yearPublished!.trim()
        : 'CLASSIFIED';
    final chaptersText = series.standaloneChapterCount != null && series.standaloneChapterCount! > 0
        ? '${series.standaloneChapterCount} CHAPTERS'
        : (series.volumeCount > 0 ? '${series.volumeCount} VOLUMES' : 'RESTRICTED ARCHIVE');
    final genresText = series.genres.isNotEmpty
        ? series.genres.map((g) => g.name.toUpperCase()).take(3).join(', ')
        : 'CLASSIFIED';
    final authorText = series.author != null && series.author!.trim().isNotEmpty
        ? series.author!.trim().toUpperCase()
        : 'UNKNOWN';

    // Full synopsis, never truncated.
    final synopsisText = (series.synopsis != null && series.synopsis!.trim().isNotEmpty)
        ? series.synopsis!.trim()
        : 'The file contains sensitive archival material on record under classified protocols.';

    final fileStyle = GoogleFonts.courierPrime(
      fontSize: 13,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.8,
      color: inkColor,
    );

    final hasCover = coverBytes != null && coverBytes!.isNotEmpty;

    return Container(
      width: cardWidth,
      color: deskColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Underlying left page edge for realistic ring-binder notebook depth
          Positioned(
            left: 0,
            top: 14,
            bottom: 14,
            width: 22,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEFECE2),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(2)),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(-1, 2)),
                ],
              ),
            ),
          ),

          // Main White/Cream Notebook Sheet (its content decides the card height)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Container(
              decoration: BoxDecoration(
                color: paperColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 10,
                    offset: Offset(2, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Content Area
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 38, 18, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Section: FILE number (blacked out), plus polaroid only when a cover exists
                        if (hasCover)
                          SizedBox(
                            height: 195,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: 6,
                                  top: 18,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('FILE: ', style: fileStyle),
                                      _redacted(fileNumber, fileStyle),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 6,
                                  top: 4,
                                  child: Transform.rotate(
                                    angle: 0.04,
                                    child: _buildPolaroid(),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('FILE: ', style: fileStyle),
                                _redacted(fileNumber, fileStyle),
                              ],
                            ),
                          ),

                        const SizedBox(height: 10),

                        // Specs table
                        Padding(
                          padding: const EdgeInsets.only(left: 6, right: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSpecRow('NEW TITLE', series.title.toUpperCase()),
                              _buildSpecRow('STATUS', series.status.toUpperCase()),
                              _buildSpecRow('REF NO', '', redactedValue: 'A$fileNumber'),
                              _buildSpecRow('AUTHOR', authorText),
                              _buildSpecRow('RELEASE', releaseYear),
                              _buildSpecRow('CHAPTERS', chaptersText),
                              _buildSpecRow('GENRE', genresText),
                              _buildSpecRow('NOTE', synopsisText, isParagraph: true),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Footer: @username (blacked out)
                        Center(
                          child: _redacted(
                            '@myaarchive',
                            GoogleFonts.cormorantGaramond(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                              color: inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Row of binder punch holes along the top
                  Positioned(
                    top: 14,
                    left: 20,
                    right: 20,
                    child: _buildPunchHoles(),
                  ),

                  // Left edge page ring-binder clips / staples
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 8,
                    child: CustomPaint(
                      painter: _BinderStaplesPainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Black bar sized to the text it hides (the text itself is not rendered).
  Widget _redacted(String text, TextStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      color: redactionColor,
      child: Text(text, style: style.copyWith(color: redactionColor)),
    );
  }

  /// Row of 7 circular punch holes along the top of the paper sheet
  Widget _buildPunchHoles() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        return Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: deskColor,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 1.5,
                offset: Offset(0, 1),
              ),
            ],
            border: Border.all(color: const Color(0x24000000), width: 0.6),
          ),
        );
      }),
    );
  }

  /// Polaroid Photo Card with brass paperclip (only built when a cover exists)
  Widget _buildPolaroid() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 140,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 8,
                offset: Offset(2, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cover thumbnail
              AspectRatio(
                aspectRatio: 0.88,
                child: Image.memory(
                  coverBytes!,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),

        // Realistic brass metal paperclip pinned to bottom-right of the photo
        Positioned(
          bottom: -10,
          right: 12,
          child: Transform.rotate(
            angle: 0.22,
            child: const SizedBox(
              width: 34,
              height: 48,
              child: CustomPaint(
                painter: _PaperclipPainter(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Single spec line in the dossier spec table. Values wrap freely; a paragraph
  /// (the synopsis) sits under its label at full width in sentence case.
  /// [redactedValue] draws the value as a black bar instead of text.
  Widget _buildSpecRow(
    String label,
    String value, {
    bool isParagraph = false,
    String? redactedValue,
  }) {
    final labelStyle = GoogleFonts.cormorantGaramond(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: inkColor,
    );
    final valueStyle = GoogleFonts.cormorantGaramond(
      fontSize: isParagraph ? 14 : 13,
      fontWeight: FontWeight.w700,
      letterSpacing: isParagraph ? 0.2 : 0.8,
      height: isParagraph ? 1.5 : 1.3,
      color: inkColor,
    );

    if (isParagraph) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label:', style: labelStyle),
            const SizedBox(height: 3),
            Text(value, style: valueStyle),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 82, child: Text(label, style: labelStyle)),
          Text(':', style: labelStyle),
          const SizedBox(width: 4),
          Expanded(
            child: redactedValue != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: _redacted(redactedValue, valueStyle),
                  )
                : Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the brass paperclip clipping the photo to the notebook page
class _PaperclipPainter extends CustomPainter {
  const _PaperclipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const wireColor = Color(0xFF8F886B);
    const shadowColor = Color(0x40000000);

    final path = Path();
    // Inner wire loop
    path.moveTo(size.width * 0.35, size.height * 0.38);
    path.lineTo(size.width * 0.35, size.height * 0.82);
    path.arcToPoint(
      Offset(size.width * 0.65, size.height * 0.82),
      radius: Radius.circular(size.width * 0.15),
      clockwise: false,
    );
    path.lineTo(size.width * 0.65, size.height * 0.18);
    path.arcToPoint(
      Offset(size.width * 0.15, size.height * 0.18),
      radius: Radius.circular(size.width * 0.25),
      clockwise: false,
    );
    path.lineTo(size.width * 0.15, size.height * 0.86);
    path.arcToPoint(
      Offset(size.width * 0.85, size.height * 0.86),
      radius: Radius.circular(size.width * 0.35),
      clockwise: false,
    );
    path.lineTo(size.width * 0.85, size.height * 0.42);

    final shadowPaint = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final wirePaint = Paint()
      ..color = wireColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw shadow first, then wire
    canvas.drawPath(path.shift(const Offset(1.2, 1.5)), shadowPaint);
    canvas.drawPath(path, wirePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for the notebook wire binder staples on the left edge
class _BinderStaplesPainter extends CustomPainter {
  const _BinderStaplesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const stapleColor = Color(0xFF7A7D75);
    const shadowColor = Color(0x33000000);

    final staplePaint = Paint()
      ..color = stapleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Top staple at y = 18%
    final topY = size.height * 0.18;
    canvas.drawLine(Offset(0, topY + 1), Offset(size.width, topY + 1), shadowPaint);
    canvas.drawLine(Offset(0, topY), Offset(size.width, topY), staplePaint);

    // Bottom staple at y = 82%
    final botY = size.height * 0.82;
    canvas.drawLine(Offset(0, botY + 1), Offset(size.width, botY + 1), shadowPaint);
    canvas.drawLine(Offset(0, botY), Offset(size.width, botY), staplePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
