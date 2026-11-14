import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/player/data/models/track_model.dart';

/// Générateur d'images de partage haute définition (format 4:5 - 1080x1350)
/// optimisé pour WhatsApp, Instagram Stories, Facebook et Twitter.
class ShareCardGenerator {
  static const double cardWidth = 1080.0;
  static const double cardHeight = 1350.0;

  /// Génère une carte visuelle stylée et l'enregistre dans un fichier PNG temporaire.
  static Future<File?> generateShareCard({
    required TrackModel track,
    required File coverFile,
    bool isSuperliked = false,
  }) async {
    try {
      final ui.Image coverImage = await _loadImageFromFile(coverFile);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, cardWidth, cardHeight));

      // 1. Fond sombre avec lueur radiale
      _drawBackground(canvas, isSuperliked);

      // 2. En-tête de marque Sonoritiz
      _drawHeader(canvas, isSuperliked);

      // 3. Pochette avec coins arrondis, relief et ombre
      _drawCover(canvas, coverImage, isSuperliked);

      // 4. Titre et Nom d'Artiste
      _drawTrackInfo(canvas, track, isSuperliked);

      // 5. Visualiseur onde audio (Waveform)
      _drawWaveform(canvas, isSuperliked);

      // 6. Pied de page / Call-to-action
      _drawFooter(canvas);

      final picture = recorder.endRecording();
      final ui.Image finalImage = await picture.toImage(cardWidth.toInt(), cardHeight.toInt());
      final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final safeId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final outputFile = File('${tempDir.path}/sonoritiz_share_$safeId.png');
      await outputFile.writeAsBytes(byteData.buffer.asUint8List());

      return outputFile;
    } catch (e) {
      debugPrint("Erreur generateShareCard: $e");
      return null;
    }
  }

  static Future<ui.Image> _loadImageFromFile(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static void _drawBackground(Canvas canvas, bool isSuperliked) {
    // Fond sombre de base
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(cardWidth / 2, 0),
        const Offset(cardWidth / 2, cardHeight),
        [
          isSuperliked ? const Color(0xFF221A0F) : const Color(0xFF14171E),
          const Color(0xFF090A0D),
        ],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, cardWidth, cardHeight), bgPaint);

    // Halo lumineux central
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(cardWidth / 2, 530),
        480,
        [
          (isSuperliked ? const Color(0xFFFFD700) : const Color(0xFFE94057)).withValues(alpha: 0.22),
          (isSuperliked ? const Color(0xFFFFA000) : const Color(0xFF8A2387)).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(const Offset(cardWidth / 2, 530), 480, glowPaint);

    // Bordure subtile extérieure
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawRect(const Rect.fromLTWH(1, 1, cardWidth - 2, cardHeight - 2), borderPaint);
  }

  static void _drawHeader(Canvas canvas, bool isSuperliked) {
    // Badge "S O N O R I T I Z"
    final tp = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: "S O N O R I T I Z",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 6.0,
            ),
          ),
          TextSpan(
            text: " •",
            style: TextStyle(
              color: isSuperliked ? const Color(0xFFFFD700) : const Color(0xFFE94057),
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((cardWidth - tp.width) / 2, 85));

    final subTp = TextPainter(
      text: TextSpan(
        text: isSuperliked ? "COUP DE CŒUR SUPERLIKE" : "LA MUSIQUE QUI VOUS RESSEMBLE",
        style: TextStyle(
          color: isSuperliked ? const Color(0xFFFFD700).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.45),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 3.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(canvas, Offset((cardWidth - subTp.width) / 2, 130));
  }

  static void _drawCover(Canvas canvas, ui.Image cover, bool isSuperliked) {
    const double coverSize = 640.0;
    const double left = (cardWidth - coverSize) / 2;
    const double top = 180.0;
    const coverRect = Rect.fromLTWH(left, top, coverSize, coverSize);
    final rrect = RRect.fromRectAndRadius(coverRect, const Radius.circular(36));

    // Ombre portée douce
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.60)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawRRect(rrect.shift(const Offset(0, 18)), shadowPaint);

    // Dessin de l'image rognée
    canvas.save();
    canvas.clipRRect(rrect);
    final srcRect = Rect.fromLTWH(0, 0, cover.width.toDouble(), cover.height.toDouble());
    canvas.drawImageRect(cover, srcRect, coverRect, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();

    // Bordure lumineuse autour de la pochette
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSuperliked ? 3.5 : 2.0
      ..shader = ui.Gradient.linear(
        const Offset(left, top),
        const Offset(left + coverSize, top + coverSize),
        [
          (isSuperliked ? const Color(0xFFFFD700) : Colors.white).withValues(alpha: isSuperliked ? 0.90 : 0.40),
          Colors.white.withValues(alpha: 0.05),
        ],
      );
    canvas.drawRRect(rrect, borderPaint);

    // Badge Superlike en haut à droite si applicable
    if (isSuperliked) {
      const double badgeW = 200.0;
      const double badgeH = 44.0;
      const badgeRect = Rect.fromLTWH(left + coverSize - badgeW - 16, top + 16, badgeW, badgeH);
      final badgeRRect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(22));

      final badgePaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(badgeW, 0),
          const [Color(0xFFFFD700), Color(0xFFFFA000)],
        );
      canvas.drawRRect(badgeRRect, badgePaint);

      final badgeTp = TextPainter(
        text: const TextSpan(
          text: "⭐ SUPERLIKE",
          style: TextStyle(
            color: Color(0xFF1E1300),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      badgeTp.paint(
        canvas,
        Offset(
          badgeRect.left + (badgeW - badgeTp.width) / 2,
          badgeRect.top + (badgeH - badgeTp.height) / 2,
        ),
      );
    }
  }

  static void _drawTrackInfo(Canvas canvas, TrackModel track, bool isSuperliked) {
    const double top = 865.0;
    const double maxTextWidth = 920.0;

    // Titre
    final titleTp = TextPainter(
      text: TextSpan(
        text: track.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.15,
        ),
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxTextWidth);
    titleTp.paint(canvas, Offset((cardWidth - titleTp.width) / 2, top));

    // Nom de l'artiste
    final artistTop = top + titleTp.height + 14.0;
    final artistTp = TextPainter(
      text: TextSpan(
        text: track.artistName,
        style: TextStyle(
          color: isSuperliked ? const Color(0xFFFFD700) : const Color(0xFFFFB74D),
          fontSize: 30,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxTextWidth);
    artistTp.paint(canvas, Offset((cardWidth - artistTp.width) / 2, artistTop));
  }

  static void _drawWaveform(Canvas canvas, bool isSuperliked) {
    const double centerY = 1075.0;
    const int barCount = 31;
    const double barWidth = 6.0;
    const double gap = 8.0;
    const double totalW = (barCount * barWidth) + ((barCount - 1) * gap);
    final double startX = (cardWidth - totalW) / 2;

    // Hauteurs d'onde harmonieuses simulées
    final heights = [
      12.0, 18.0, 26.0, 36.0, 48.0, 32.0, 56.0, 72.0, 44.0, 64.0,
      82.0, 52.0, 74.0, 92.0, 68.0, 88.0, 96.0, 78.0, 60.0, 80.0,
      64.0, 48.0, 68.0, 54.0, 38.0, 44.0, 30.0, 22.0, 18.0, 14.0, 10.0,
    ];

    for (int i = 0; i < barCount; i++) {
      final x = startX + i * (barWidth + gap);
      final h = heights[i % heights.length] * 0.65;
      final rect = Rect.fromLTWH(x, centerY - h / 2, barWidth, h);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));

      final barPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, centerY - h / 2),
          Offset(x, centerY + h / 2),
          [
            isSuperliked ? const Color(0xFFFFD700) : const Color(0xFFFF8A65),
            Colors.white.withValues(alpha: 0.45),
          ],
        );
      canvas.drawRRect(rrect, barPaint);
    }
  }

  static void _drawFooter(Canvas canvas) {
    const double bottom = 1180.0;
    const double pillW = 440.0;
    const double pillH = 68.0;
    final pillRect = const Rect.fromLTWH((cardWidth - pillW) / 2, bottom, pillW, pillH);
    final pillRRect = RRect.fromRectAndRadius(pillRect, const Radius.circular(34));

    // Fond du bouton Call-to-Action
    final pillBg = Paint()
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawRRect(pillRRect, pillBg);

    final pillBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawRRect(pillRRect, pillBorder);

    // Texte avec icône de lecture
    final ctaTp = TextPainter(
      text: const TextSpan(
        children: [
          TextSpan(
            text: "▶  ÉCOUTER SUR SONORITIZ",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ctaTp.paint(
      canvas,
      Offset(
        pillRect.left + (pillW - ctaTp.width) / 2,
        pillRect.top + (pillH - ctaTp.height) / 2,
      ),
    );
  }

  /// Génère une affiche collector HD 9:16 dédiée au Wrapped pour WhatsApp / Instagram Stories
  static Future<File?> generateWrappedShareCard({
    required String username,
    required String personaTitle,
    required int totalMinutes,
    required int totalPlays,
    required List<String> topTracks,
    required List<String> topArtists,
    File? topCoverFile,
  }) async {
    try {
      const double w = 1080.0;
      const double h = 1920.0;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

      // 1. Fond cosmique sombre avec lueur dorée et violette
      final bgPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(w / 2, 0),
          const Offset(w / 2, h),
          const [
            Color(0xFF221338),
            Color(0xFF12121E),
            Color(0xFF09090D),
          ],
        );
      canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), bgPaint);

      // Lueur radiale ambrée au sommet
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          const Offset(w / 2, 420),
          520,
          [
            const Color(0xFFFFD54F).withValues(alpha: 0.18),
            Colors.transparent,
          ],
        );
      canvas.drawCircle(const Offset(w / 2, 420), 520, glowPaint);

      // 2. En-tête officiel Sonoritiz
      final headerTp = TextPainter(
        text: const TextSpan(
          text: "SONORITIZ  WRAPPED",
          style: TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 6.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      headerTp.paint(canvas, Offset((w - headerTp.width) / 2, 130));

      final subHeaderTp = TextPainter(
        text: TextSpan(
          text: "L'ODYSSÉE MUSICALE DE ${username.toUpperCase()}",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      subHeaderTp.paint(canvas, Offset((w - subHeaderTp.width) / 2, 180));

      // 3. Pochette #1 si disponible
      double currentY = 250.0;
      if (topCoverFile != null && topCoverFile.existsSync()) {
        try {
          final coverImg = await _loadImageFromFile(topCoverFile);
          final coverRect = Rect.fromLTWH((w - 380) / 2, currentY, 380, 380);
          final coverRRect = RRect.fromRectAndRadius(coverRect, const Radius.circular(28));

          // Ombre portée
          final shadowPaint = Paint()
            ..color = const Color(0xFFFFD54F).withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
          canvas.drawRRect(coverRRect, shadowPaint);

          canvas.save();
          canvas.clipRRect(coverRRect);
          canvas.drawImageRect(
            coverImg,
            Rect.fromLTWH(0, 0, coverImg.width.toDouble(), coverImg.height.toDouble()),
            coverRect,
            Paint()..filterQuality = FilterQuality.medium,
          );
          canvas.restore();
          currentY += 410.0;
        } catch (_) {
          currentY += 60.0;
        }
      } else {
        currentY += 40.0;
      }

      // 4. Titre de Persona / Identité sonore
      final personaTp = TextPainter(
        text: TextSpan(
          text: personaTitle.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      personaTp.paint(canvas, Offset((w - personaTp.width) / 2, currentY));
      currentY += 80.0;

      // 5. Deux piliers de chiffres (Minutes & Titres)
      const pillW = 420.0;
      const pillH = 110.0;
      final leftPill = Rect.fromLTWH(80, currentY, pillW, pillH);
      final rightPill = Rect.fromLTWH(w - 80 - pillW, currentY, pillW, pillH);

      final pBg = Paint()..color = Colors.white.withValues(alpha: 0.08);
      final pBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.16);

      canvas.drawRRect(RRect.fromRectAndRadius(leftPill, const Radius.circular(22)), pBg);
      canvas.drawRRect(RRect.fromRectAndRadius(leftPill, const Radius.circular(22)), pBorder);
      canvas.drawRRect(RRect.fromRectAndRadius(rightPill, const Radius.circular(22)), pBg);
      canvas.drawRRect(RRect.fromRectAndRadius(rightPill, const Radius.circular(22)), pBorder);

      final minValTp = TextPainter(
        text: TextSpan(
          text: "$totalMinutes",
          style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 40, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      minValTp.paint(canvas, Offset(leftPill.left + 24, leftPill.top + 16));

      final minLabelTp = TextPainter(
        text: const TextSpan(
          text: "MINUTES D'ÉCOUTE",
          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      minLabelTp.paint(canvas, Offset(leftPill.left + 24, leftPill.top + 68));

      final playsValTp = TextPainter(
        text: TextSpan(
          text: "$totalPlays",
          style: const TextStyle(color: Color(0xFFFF8A65), fontSize: 40, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      playsValTp.paint(canvas, Offset(rightPill.left + 24, rightPill.top + 16));

      final playsLabelTp = TextPainter(
        text: const TextSpan(
          text: "TITRES JOUÉS",
          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      playsLabelTp.paint(canvas, Offset(rightPill.left + 24, rightPill.top + 68));

      currentY += 150.0;

      // 6. Top 5 Titres
      final t5HeaderTp = TextPainter(
        text: const TextSpan(
          text: "VOS TITRES LES PLUS ÉCOUTÉS",
          style: TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t5HeaderTp.paint(canvas, Offset(90, currentY));
      currentY += 34.0;

      for (int i = 0; i < topTracks.take(5).length; i++) {
        final rank = i + 1;
        final trackLine = topTracks[i];
        final lineTp = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(
                text: "#$rank  ",
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: trackLine,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        )..layout(maxWidth: w - 180);
        lineTp.paint(canvas, Offset(90, currentY));
        currentY += 46.0;
      }

      currentY += 30.0;

      // 7. Top 3 Artistes
      if (topArtists.isNotEmpty) {
        final aHeaderTp = TextPainter(
          text: const TextSpan(
            text: "PODIUM DES ARTISTES",
            style: TextStyle(
              color: Color(0xFFFF8A65),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        aHeaderTp.paint(canvas, Offset(90, currentY));
        currentY += 34.0;

        final aLineTp = TextPainter(
          text: TextSpan(
            text: topArtists.take(3).join("  •  "),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        )..layout(maxWidth: w - 180);
        aLineTp.paint(canvas, Offset(90, currentY));
      }

      // 8. Pied de page Sonoritiz
      const footerBg = Rect.fromLTWH(0, h - 140, w, 140);
      canvas.drawRect(footerBg, Paint()..color = Colors.black.withValues(alpha: 0.45));

      final fBrandTp = TextPainter(
        text: const TextSpan(
          children: [
            TextSpan(
              text: "SONORITIZ",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 4.0,
              ),
            ),
            TextSpan(
              text: "  •  Votre plateforme de streaming",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      fBrandTp.paint(canvas, Offset((w - fBrandTp.width) / 2, h - 85));

      final picture = recorder.endRecording();
      final ui.Image finalImage = await picture.toImage(w.toInt(), h.toInt());
      final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final outputFile = File('${tempDir.path}/sonoritiz_wrapped_${DateTime.now().millisecondsSinceEpoch}.png');
      await outputFile.writeAsBytes(byteData.buffer.asUint8List());

      return outputFile;
    } catch (e) {
      debugPrint("Erreur generateWrappedShareCard: $e");
      return null;
    }
  }
}
