import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/player/data/models/track_model.dart';

/// Les 3 polices signature disponibles lors du partage (Paroles & Son en cours).
enum SonoritizShareFont {
  /// Typographie display expressive, ronde et audacieuse (style urbain / punchline)
  matey,

  /// Typographie éditoriale serif aux empattements élégants (style citation littéraire)
  fontaine,

  /// Typographie géométrique condensée et massive (style affiche / poster)
  etna,
}

extension SonoritizShareFontX on SonoritizShareFont {
  String get label {
    switch (this) {
      case SonoritizShareFont.matey:
        return 'Matey';
      case SonoritizShareFont.fontaine:
        return 'Fontaine';
      case SonoritizShareFont.etna:
        return 'Etna';
    }
  }

  TextStyle textStyle({
    required double fontSize,
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w800,
    double height = 1.24,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    switch (this) {
      case SonoritizShareFont.matey:
        return GoogleFonts.syne(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing ?? -0.4,
          shadows: shadows,
        );
      case SonoritizShareFont.fontaine:
        return GoogleFonts.playfairDisplay(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: FontStyle.italic,
          height: height,
          letterSpacing: letterSpacing ?? -0.1,
          shadows: shadows,
        );
      case SonoritizShareFont.etna:
        return GoogleFonts.oswald(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing ?? 0.5,
          shadows: shadows,
        );
    }
  }
}

/// Générateur d'images de partage haute définition (format 4:5 - 1080x1350)
/// optimisé pour WhatsApp, Statut, Instagram Stories, SMS et réseaux sociaux.
class ShareCardGenerator {
  static const double cardWidth = 1080.0;
  static const double cardHeight = 1350.0;

  /// Construit 3 couleurs de background distinctes à partir des couleurs dominantes de la pochette.
  static List<Color> buildThreeCoverBackgrounds({
    required Color dominant,
    required Color accent,
    required Color deep,
  }) {
    final hslDom = HSLColor.fromColor(dominant);
    final Color c1 = hslDom
        .withSaturation((hslDom.saturation * 0.92).clamp(0.22, 0.82))
        .withLightness(hslDom.lightness.clamp(0.22, 0.44))
        .toColor();

    final hslAcc = HSLColor.fromColor(accent);
    final double hueDiff12 = (hslAcc.hue - hslDom.hue).abs();
    final Color c2 = (hueDiff12 < 14 &&
            (hslAcc.lightness - hslDom.lightness).abs() < 0.12)
        ? hslDom
            .withHue((hslDom.hue + 28) % 360)
            .withSaturation((hslDom.saturation * 1.15).clamp(0.32, 0.88))
            .withLightness((hslDom.lightness * 0.82).clamp(0.18, 0.36))
            .toColor()
        : hslAcc
            .withSaturation(hslAcc.saturation.clamp(0.26, 0.85))
            .withLightness(hslAcc.lightness.clamp(0.20, 0.40))
            .toColor();

    final hslDeep = HSLColor.fromColor(deep);
    final Color c3 = hslDeep
        .withSaturation(hslDeep.saturation.clamp(0.18, 0.65))
        .withLightness(hslDeep.lightness.clamp(0.11, 0.22))
        .toColor();

    return <Color>[c1, c2, c3];
  }

  /// Pré-charge la police GoogleFonts choisie avant le rendu sur Canvas.
  static Future<void> ensureFontLoaded(SonoritizShareFont font) async {
    try {
      // Déclenche l'enregistrement de la police dans FontLoader
      font.textStyle(fontSize: 24);
      await GoogleFonts.pendingFonts()
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }

  /// Nettoie une ligne de paroles en retirant tous les guillemets encadrants (« », "", “”).
  static String cleanLyricLine(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'^[«"“”„‟\s]+'), '')
        .replaceAll(RegExp(r'[»"“”„‟\s]+$'), '')
        .trim();
  }

  /// Génère la Carte de Partage du Son en cours (style carte flottante Spotify + ADN Sonoritiz) :
  /// - Fond : l'une des 3 couleurs dominantes de la pochette OU la pochette floutée grand format
  /// - Carte centrale flottante sombre avec grande pochette carrée HD
  /// - Sous la pochette : Titre (avec police Matey / Fontaine / Etna) + Artiste
  /// - En bas à gauche de la carte : Vrai logo d'origine (orange & blanc) + "Sonoritiz"
  /// - En bas à droite de la carte : Mini-onde acoustique (ou badge Superlike).
  static Future<File?> generateShareCard({
    required TrackModel track,
    required File coverFile,
    bool isSuperliked = false,
    Color backgroundColor = const Color(0xFF3E4046),
    bool useBlurredCoverBackground = false,
    SonoritizShareFont font = SonoritizShareFont.matey,
    bool showAcousticWave = true,
  }) async {
    try {
      await ensureFontLoaded(font);
      final ui.Image coverImage = await _loadImageFromFile(coverFile);
      final ui.Image? appLogoImage =
          await _loadAssetImage('assets/images/app_logo.png');

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        const Rect.fromLTWH(0, 0, cardWidth, cardHeight),
      );

      // 1. Toile de fond extérieure (Couleur dominante de la pochette OU Pochette floutée)
      if (useBlurredCoverBackground) {
        canvas.save();
        final bgRect = const Rect.fromLTWH(0, 0, cardWidth, cardHeight);
        // Élargir légèrement pour éviter les bords transparents du flou
        final expandedRect = bgRect.inflate(80);
        canvas.drawImageRect(
          coverImage,
          Rect.fromLTWH(
            0,
            0,
            coverImage.width.toDouble(),
            coverImage.height.toDouble(),
          ),
          expandedRect,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
        );
        canvas.restore();
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, cardWidth, cardHeight),
          Paint()..color = backgroundColor.withValues(alpha: 0.38),
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, cardWidth, cardHeight),
          Paint()..color = Colors.black.withValues(alpha: 0.28),
        );
      } else {
        final Color topBg =
            Color.lerp(backgroundColor, Colors.white, 0.08) ?? backgroundColor;
        final Color bottomBg =
            Color.lerp(backgroundColor, const Color(0xFF0A0A0E), 0.34) ??
                backgroundColor;
        final bgPaint = Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 0),
            const Offset(0, cardHeight),
            [topBg, backgroundColor, bottomBg],
            const [0.0, 0.55, 1.0],
          );
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, cardWidth, cardHeight),
          bgPaint,
        );
      }

      // 2. Carte centrale flottante (inspirée du layout Spotify + signature Sonoritiz)
      const double innerW = 816.0;
      const double innerH = 1056.0;
      const double innerLeft = (cardWidth - innerW) / 2;
      const double innerTop = (cardHeight - innerH) / 2;
      const Rect innerRect =
          Rect.fromLTWH(innerLeft, innerTop, innerW, innerH);
      final RRect innerRRect =
          RRect.fromRectAndRadius(innerRect, const Radius.circular(42));

      // Ombre portée profonde sous la carte centrale
      canvas.drawRRect(
        innerRRect.shift(const Offset(0, 22)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.52)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38),
      );

      final Color cardSurfaceColor =
          Color.lerp(backgroundColor, const Color(0xFF141519), 0.74) ??
              const Color(0xFF1C1D22);
      canvas.drawRRect(innerRRect, Paint()..color = cardSurfaceColor);
      canvas.drawRRect(
        innerRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = Colors.white.withValues(alpha: 0.12),
      );

      // 3. Grande Pochette carrée HD en haut de la carte flottante
      const double coverPad = 48.0;
      const double coverSize = innerW - (coverPad * 2); // 720x720
      const double coverLeft = innerLeft + coverPad;
      const double coverTop = innerTop + coverPad;
      const Rect coverRect =
          Rect.fromLTWH(coverLeft, coverTop, coverSize, coverSize);
      final RRect coverRRect =
          RRect.fromRectAndRadius(coverRect, const Radius.circular(22));

      canvas.drawRRect(
        coverRRect.shift(const Offset(0, 10)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.38)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );

      canvas.save();
      canvas.clipRRect(coverRRect);
      canvas.drawImageRect(
        coverImage,
        Rect.fromLTWH(
          0,
          0,
          coverImage.width.toDouble(),
          coverImage.height.toDouble(),
        ),
        coverRect,
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();

      // 4. Titre & Nom d'artiste alignés à gauche sous la pochette
      const double textLeft = coverLeft + 4.0;
      const double maxTextW = coverSize - 8.0;
      const double titleTop = coverTop + coverSize + 36.0;

      final titleTp = TextPainter(
        text: TextSpan(
          text: track.title,
          style: font.textStyle(
            fontSize: 44,
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.14,
          ),
        ),
        maxLines: 1,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxTextW);
      titleTp.paint(canvas, const Offset(textLeft, titleTop));

      final double artistTop = titleTop + titleTp.height + 8.0;
      final artistTp = TextPainter(
        text: TextSpan(
          text: track.artistName,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        maxLines: 1,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxTextW);
      artistTp.paint(canvas, Offset(textLeft, artistTop));

      // 5. Pied de la carte flottante : [Vrai Logo d'origine] + "Sonoritiz" à gauche
      const double brandRowY = innerTop + innerH - 86.0;
      const double logoSize = 46.0;
      const Rect logoRect =
          Rect.fromLTWH(textLeft, brandRowY, logoSize, logoSize);
      final RRect logoRRect =
          RRect.fromRectAndRadius(logoRect, const Radius.circular(13));

      canvas.drawRRect(logoRRect, Paint()..color = Colors.black);
      if (appLogoImage != null) {
        canvas.save();
        canvas.clipRRect(logoRRect);
        canvas.drawImageRect(
          appLogoImage,
          Rect.fromLTWH(
            0,
            0,
            appLogoImage.width.toDouble(),
            appLogoImage.height.toDouble(),
          ),
          logoRect,
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.restore();
      }

      final brandTp = TextPainter(
        text: const TextSpan(
          text: 'Sonoritiz',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      brandTp.paint(
        canvas,
        Offset(
          textLeft + logoSize + 14.0,
          brandRowY + (logoSize - brandTp.height) / 2,
        ),
      );

      // 6. En bas à droite de la carte : Mini-onde acoustique ou badge Superlike
      if (showAcousticWave) {
        const List<double> bars = [
          14.0,
          24.0,
          36.0,
          22.0,
          40.0,
          30.0,
          18.0,
          32.0,
          16.0,
        ];
        const double barW = 5.5;
        const double gap = 6.5;
        final double totalWaveW =
            bars.length * barW + (bars.length - 1) * gap;
        final double startX = (coverLeft + coverSize) - totalWaveW - 4.0;
        const double centerY = brandRowY + logoSize / 2;
        final Color waveColor = isSuperliked
            ? const Color(0xFFFFD54F)
            : (Color.lerp(backgroundColor, const Color(0xFFFA7921), 0.55) ??
                const Color(0xFFFA7921));

        for (int i = 0; i < bars.length; i++) {
          final double hBar = bars[i];
          final double x = startX + i * (barW + gap);
          final RRect barRRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, centerY - hBar / 2, barW, hBar),
            const Radius.circular(3),
          );
          canvas.drawRRect(
            barRRect,
            Paint()
              ..color = waveColor.withValues(alpha: i.isEven ? 0.95 : 0.72),
          );
        }
      }

      final picture = recorder.endRecording();
      final ui.Image finalImage =
          await picture.toImage(cardWidth.toInt(), cardHeight.toInt());
      final ByteData? byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final safeId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final outputFile = File(
        '${tempDir.path}/sonoritiz_share_${safeId}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
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
          final coverRRect =
              RRect.fromRectAndRadius(coverRect, const Radius.circular(28));

          final shadowPaint = Paint()
            ..color = const Color(0xFFFFD54F).withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
          canvas.drawRRect(coverRRect, shadowPaint);

          canvas.save();
          canvas.clipRRect(coverRRect);
          canvas.drawImageRect(
            coverImg,
            Rect.fromLTWH(
                0, 0, coverImg.width.toDouble(), coverImg.height.toDouble()),
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

      canvas.drawRRect(
          RRect.fromRectAndRadius(leftPill, const Radius.circular(22)), pBg);
      canvas.drawRRect(
          RRect.fromRectAndRadius(leftPill, const Radius.circular(22)),
          pBorder);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rightPill, const Radius.circular(22)), pBg);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rightPill, const Radius.circular(22)),
          pBorder);

      final minValTp = TextPainter(
        text: TextSpan(
          text: "$totalMinutes",
          style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 40,
              fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      minValTp.paint(canvas, Offset(leftPill.left + 24, leftPill.top + 16));

      final minLabelTp = TextPainter(
        text: const TextSpan(
          text: "MINUTES D'ÉCOUTE",
          style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      minLabelTp.paint(canvas, Offset(leftPill.left + 24, leftPill.top + 68));

      final playsValTp = TextPainter(
        text: TextSpan(
          text: "$totalPlays",
          style: const TextStyle(
              color: Color(0xFFFF8A65),
              fontSize: 40,
              fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      playsValTp.paint(canvas, Offset(rightPill.left + 24, rightPill.top + 16));

      final playsLabelTp = TextPainter(
        text: const TextSpan(
          text: "TITRES JOUÉS",
          style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      playsLabelTp.paint(
          canvas, Offset(rightPill.left + 24, rightPill.top + 68));

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
      canvas.drawRect(
          footerBg, Paint()..color = Colors.black.withValues(alpha: 0.45));

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
      final ByteData? byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final outputFile = File(
          '${tempDir.path}/sonoritiz_wrapped_${DateTime.now().millisecondsSinceEpoch}.png');
      await outputFile.writeAsBytes(byteData.buffer.asUint8List());

      return outputFile;
    } catch (e) {
      debugPrint("Erreur generateWrappedShareCard: $e");
      return null;
    }
  }

  static Future<ui.Image?> _loadAssetImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  /// Génère une Carte Visuelle de Paroles (« Sonoritiz Lyric Card » 1080x1350) :
  /// - Fond teinté avec celle des 3 couleurs dominantes de la pochette choisie par l'utilisateur
  /// - En haut à gauche : Pochette + Titre + Artiste
  /// - Au centre : 1 à 4 lignes de paroles en GRAND format, SANS guillemets, avec la police choisie (`Matey`, `Fontaine`, `Etna`)
  ///   et `assets/images/app_logo_foreground.png` (vrai logo d'origine orange/blanc) en filigrane central
  /// - En bas à gauche : "[Nom d'artiste] a dit !" (sans texte SONORITIZ ni Paroles...)
  /// - En bas à droite : Vrai logo d'origine de l'application (`assets/images/app_logo.png`).
  static Future<File?> generateLyricsShareCard({
    required TrackModel track,
    required List<String> lyricLines,
    File? coverFile,
    Color dominantColor = const Color(0xFF23364C),
    Color deepColor = const Color(0xFF10151E),
    Color accentColor = const Color(0xFFFA7921),
    SonoritizShareFont font = SonoritizShareFont.matey,
  }) async {
    try {
      await ensureFontLoaded(font);
      const double w = 1080.0;
      const double h = 1350.0;

      final ui.Image? coverImage =
          (coverFile != null && coverFile.existsSync())
              ? await _loadImageFromFile(coverFile)
              : null;
      // Logo d'origine de l'application (bécarre blanc + 8 cercles concentriques orange #FA7921)
      final ui.Image? originalAppLogo =
          await _loadAssetImage('assets/images/app_logo.png');
      final ui.Image? originalForegroundLogo =
          await _loadAssetImage('assets/images/app_logo_foreground.png');

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

      final Color topTint =
          Color.lerp(dominantColor, Colors.white, 0.06) ?? dominantColor;
      final Color midTint =
          Color.lerp(dominantColor, const Color(0xFF0E1017), 0.32) ??
              dominantColor;
      final Color bottomTint =
          Color.lerp(dominantColor, const Color(0xFF07080C), 0.58) ??
              deepColor;

      // 1. Fond dégradé chromatique de la couleur dominante choisie
      final bgPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(w, h),
          [topTint, midTint, bottomTint],
          const [0.0, 0.54, 1.0],
        );
      canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), bgPaint);

      // Lueur radiale douce
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          const Offset(w * 0.5, h * 0.48),
          560,
          [
            dominantColor.withValues(alpha: 0.28),
            accentColor.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          const [0.0, 0.55, 1.0],
        );
      canvas.drawCircle(const Offset(w * 0.5, h * 0.48), 560, glowPaint);

      // Cadre intérieur vitré
      const Rect cardRect = Rect.fromLTWH(48, 48, w - 96, h - 96);
      final RRect cardRRect =
          RRect.fromRectAndRadius(cardRect, const Radius.circular(48));
      canvas.drawRRect(
        cardRRect,
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
      canvas.drawRRect(
        cardRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = Colors.white.withValues(alpha: 0.20),
      );

      // 2. Filigrane central du logo d'origine (orange & blanc) derrière les paroles
      final ui.Image? wmLogo = originalForegroundLogo ?? originalAppLogo;
      if (wmLogo != null) {
        const double wmSize = 470.0;
        const Rect wmRect = Rect.fromLTWH(
          (w - wmSize) / 2,
          (h - wmSize) / 2 + 10,
          wmSize,
          wmSize,
        );
        canvas.drawImageRect(
          wmLogo,
          Rect.fromLTWH(
            0,
            0,
            wmLogo.width.toDouble(),
            wmLogo.height.toDouble(),
          ),
          wmRect,
          Paint()
            ..filterQuality = FilterQuality.high
            ..color = Colors.white.withValues(alpha: 0.11),
        );
      }

      // 3. En-tête excentré en haut à gauche : Pochette + Titre + Artiste
      const double headerLeft = 104.0;
      const double headerTop = 104.0;
      const double coverSize = 136.0;
      const Rect coverRect =
          Rect.fromLTWH(headerLeft, headerTop, coverSize, coverSize);
      final RRect coverRRect =
          RRect.fromRectAndRadius(coverRect, const Radius.circular(28));

      canvas.drawRRect(
        coverRRect.shift(const Offset(0, 10)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );

      if (coverImage != null) {
        canvas.save();
        canvas.clipRRect(coverRRect);
        canvas.drawImageRect(
          coverImage,
          Rect.fromLTWH(
            0,
            0,
            coverImage.width.toDouble(),
            coverImage.height.toDouble(),
          ),
          coverRect,
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.restore();
      } else {
        canvas.drawRRect(
          coverRRect,
          Paint()..color = const Color(0xFF1A1A22),
        );
      }
      canvas.drawRRect(
        coverRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white.withValues(alpha: 0.28),
      );

      const double textLeft = headerLeft + coverSize + 32.0;
      const double maxHeaderTextW = w - textLeft - 104.0;

      final titleTp = TextPainter(
        text: TextSpan(
          text: track.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        maxLines: 2,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxHeaderTextW);
      titleTp.paint(canvas, const Offset(textLeft, headerTop + 14));

      final artistTp = TextPainter(
        text: TextSpan(
          text: track.artistName,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.80),
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        maxLines: 1,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxHeaderTextW);
      artistTp.paint(
        canvas,
        Offset(textLeft, headerTop + 22 + titleTp.height),
      );

      // Ligne séparatrice subtile sous l'en-tête
      canvas.drawLine(
        const Offset(104, 282),
        const Offset(w - 104, 282),
        Paint()
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.15),
      );

      // 4. Paroles sélectionnées au centre : GRAND FORMAT & SANS GUILLEMETS
      final cleanedLines = lyricLines
          .map(cleanLyricLine)
          .where((l) => l.isNotEmpty && l != '♪')
          .take(4)
          .toList();
      final String joinedLyrics = cleanedLines.isNotEmpty
          ? cleanedLines.join('\n\n')
          : cleanLyricLine(track.title);

      double targetFontSize = cleanedLines.length <= 1
          ? 74.0
          : (cleanedLines.length == 2
              ? 62.0
              : (cleanedLines.length == 3 ? 54.0 : 47.0));

      const double zoneTop = 306.0;
      const double zoneBottom = 1112.0;
      const double maxLyricsHeight = zoneBottom - zoneTop;
      const double maxLyricsWidth = w - 208.0;

      late TextPainter lyricsTp;
      while (targetFontSize >= 32.0) {
        lyricsTp = TextPainter(
          text: TextSpan(
            text: joinedLyrics,
            style: font.textStyle(
              fontSize: targetFontSize,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.24,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.44),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxLyricsWidth);

        if (lyricsTp.height <= maxLyricsHeight) {
          break;
        }
        targetFontSize -= 2.0;
      }

      final double lyricsTop =
          (zoneTop + (maxLyricsHeight - lyricsTp.height) / 2)
              .clamp(zoneTop, zoneBottom - 80);
      lyricsTp.paint(canvas, Offset(104, lyricsTop));

      // 5. Pied de carte : "[Nom d'artiste] a dit !" à gauche + Vrai logo d'origine en bas à droite
      const double footerY = 1146.0;
      canvas.drawLine(
        const Offset(104, footerY - 22),
        const Offset(w - 104, footerY - 22),
        Paint()
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.15),
      );

      final String cleanArtist = track.artistName.trim().isNotEmpty
          ? track.artistName.trim()
          : 'L’artiste';

      final saidTp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: cleanArtist,
              style: font.textStyle(
                fontSize: 34,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            TextSpan(
              text: ' a dit !',
              style: font.textStyle(
                fontSize: 34,
                color: const Color(0xFFFA7921),
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ],
        ),
        maxLines: 1,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w - 340);

      // Médaillon officiel en bas à droite avec le logo d'origine de l'application (app_logo.png)
      const double badgeSize = 94.0;
      const Rect badgeRect = Rect.fromLTWH(
        w - 104 - badgeSize,
        footerY - 2,
        badgeSize,
        badgeSize,
      );
      final RRect badgeRRect =
          RRect.fromRectAndRadius(badgeRect, const Radius.circular(24));

      saidTp.paint(
        canvas,
        Offset(104, badgeRect.top + (badgeSize - saidTp.height) / 2),
      );

      canvas.drawRRect(
        badgeRRect,
        Paint()..color = Colors.black,
      );
      if (originalAppLogo != null) {
        canvas.save();
        canvas.clipRRect(badgeRRect);
        canvas.drawImageRect(
          originalAppLogo,
          Rect.fromLTWH(
            0,
            0,
            originalAppLogo.width.toDouble(),
            originalAppLogo.height.toDouble(),
          ),
          badgeRect,
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.restore();
      }
      canvas.drawRRect(
        badgeRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white.withValues(alpha: 0.24),
      );

      final picture = recorder.endRecording();
      final ui.Image finalImage =
          await picture.toImage(w.toInt(), h.toInt());
      final ByteData? byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final safeId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final outputFile = File(
        '${tempDir.path}/sonoritiz_lyrics_${safeId}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(byteData.buffer.asUint8List());
      return outputFile;
    } catch (e) {
      debugPrint("Erreur generateLyricsShareCard: $e");
      return null;
    }
  }
}
