import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/palette_service.dart';
import '../storage/storage_service.dart';
import '../widgets/sonoritiz_share_studio_sheet.dart';
import '../../features/player/data/models/track_model.dart';
import 'share_card_generator.dart';

class ShareUtils {
  /// Formate un message texte WhatsApp avec typographie markdown, emojis et séparateurs élégants.
  static String formatShareText(TrackModel track, {bool isSuperliked = false}) {
    final durationStr = track.durationSeconds > 0
        ? "${(track.durationSeconds ~/ 60).toString().padLeft(2, '0')}:${(track.durationSeconds % 60).toString().padLeft(2, '0')}"
        : null;

    final buffer = StringBuffer();
    buffer.writeln(
      isSuperliked ? "⭐ *Sonoritiz Superlike*" : "✨ *Sonoritiz Music*",
    );
    buffer.writeln("━━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("🎵 *${track.title.trim()}*");
    buffer.writeln("🎤 *${track.artistName.trim()}*");
    if (durationStr != null) {
      buffer.writeln("⏱️ _Durée : ${durationStr}_");
    }
    if (track.albumName.isNotEmpty && track.albumName != track.title) {
      buffer.writeln("💿 _Album : ${track.albumName}_");
    }
    buffer.writeln("");
    buffer.writeln(
      "🎧 Écoute ce chef-d'œuvre en haute qualité sur Sonoritiz :",
    );
    buffer.writeln("👉 https://sonoritiz.com/track/${track.id}");
    buffer.writeln("━━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("🔥 _Vibre au rythme de tes sons préférés_");
    return buffer.toString();
  }

  static Future<File?> _resolveLocalCoverFile(TrackModel track) async {
    if (track.coverUrl.isEmpty) return null;
    try {
      final tempDir = await getTemporaryDirectory();
      final uri = Uri.parse(track.coverUrl);
      String ext = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last.split('.').last
          : 'jpg';
      if (!['jpg', 'jpeg', 'png'].contains(ext.toLowerCase())) {
        ext = 'jpg';
      }

      final safeId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final localPath = '${tempDir.path}/share_raw_$safeId.$ext';
      final file = File(localPath);

      if (!await file.exists() || await file.length() < 512) {
        if (track.coverUrl.startsWith('file://')) {
          final rawLocal = track.coverUrl.replaceFirst('file://', '');
          final rawFile = File(rawLocal);
          if (await rawFile.exists()) {
            await rawFile.copy(localPath);
          }
        } else if (track.coverUrl.startsWith('/') ||
            RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(track.coverUrl)) {
          final rawFile = File(track.coverUrl);
          if (await rawFile.exists()) {
            await rawFile.copy(localPath);
          }
        } else {
          final dio = Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );
          await dio.download(track.coverUrl, localPath);
        }
      }
      if (await file.exists() && await file.length() >= 256) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Ouvre le Studio de Partage Sonoritiz (si `context` est fourni) ou exporte directement la carte du son.
  static Future<void> shareTrack(
    TrackModel track, {
    BuildContext? context,
  }) async {
    if (context != null && context.mounted) {
      await SonoritizShareStudioSheet.showForTrack(context, track: track);
      return;
    }

    final bool isSuperliked = StorageService()
        .getSuperlikesRaw()
        .any((item) => item['id']?.toString() == track.id);
    final palette = await PaletteService.getPalette(track.coverUrl);
    await exportAndShareTrackCard(
      track: track,
      backgroundColor: palette.dominantColor,
      isSuperliked: isSuperliked,
    );
  }

  /// Exporte la carte de partage du son en cours (style carte flottante Spotify + ADN Sonoritiz) et ouvre le sélecteur système.
  static Future<void> exportAndShareTrackCard({
    required TrackModel track,
    required Color backgroundColor,
    bool useBlurredCoverBackground = false,
    SonoritizShareFont font = SonoritizShareFont.matey,
    bool showAcousticWave = true,
    bool isSuperliked = false,
  }) async {
    final text = formatShareText(track, isSuperliked: isSuperliked);
    try {
      final coverFile = await _resolveLocalCoverFile(track);
      if (coverFile != null) {
        final cardFile = await ShareCardGenerator.generateShareCard(
          track: track,
          coverFile: coverFile,
          isSuperliked: isSuperliked,
          backgroundColor: backgroundColor,
          useBlurredCoverBackground: useBlurredCoverBackground,
          font: font,
          showAcousticWave: showAcousticWave,
        );
        if (cardFile != null && await cardFile.exists()) {
          await Share.shareXFiles(
            [XFile(cardFile.path, mimeType: 'image/png')],
            text: text,
          );
          return;
        }
        await Share.shareXFiles([XFile(coverFile.path)], text: text);
        return;
      }
    } catch (_) {}
    await Share.share(text);
  }

  /// Ouvre le Studio de Partage des Paroles (avec choix des 3 polices Matey / Fontaine / Etna et des 3 backgrounds de la pochette).
  static Future<void> shareLyricsCard({
    BuildContext? context,
    required TrackModel track,
    required List<String> lyricLines,
    required Color dominantColor,
    required Color deepColor,
    required Color accentColor,
  }) async {
    if (context != null && context.mounted) {
      await SonoritizShareStudioSheet.showForLyrics(
        context,
        track: track,
        lyricLines: lyricLines,
        dominantColor: dominantColor,
        accentColor: accentColor,
        deepColor: deepColor,
      );
      return;
    }

    await exportAndShareLyricsCard(
      track: track,
      lyricLines: lyricLines,
      backgroundColor: dominantColor,
      deepColor: deepColor,
      accentColor: accentColor,
    );
  }

  /// Génère la Carte Visuelle de Paroles (« [Artiste] a dit ! », sans guillemets, police & couleur choisies, vrai logo d'origine)
  /// et ouvre le sélecteur de partage système.
  static Future<void> exportAndShareLyricsCard({
    required TrackModel track,
    required List<String> lyricLines,
    required Color backgroundColor,
    required Color deepColor,
    required Color accentColor,
    SonoritizShareFont font = SonoritizShareFont.matey,
  }) async {
    final cleanedLines = lyricLines
        .map(ShareCardGenerator.cleanLyricLine)
        .where((l) => l.isNotEmpty)
        .toList();
    final quoteBlock = cleanedLines.join('\n');
    final caption =
        "$quoteBlock\n\n— *${track.artistName} a dit !* (${track.title})\n🎧 https://sonoritiz.com/track/${track.id}";

    try {
      final coverFile = await _resolveLocalCoverFile(track);
      final cardFile = await ShareCardGenerator.generateLyricsShareCard(
        track: track,
        lyricLines: cleanedLines,
        coverFile: coverFile,
        dominantColor: backgroundColor,
        deepColor: deepColor,
        accentColor: accentColor,
        font: font,
      );

      if (cardFile != null && await cardFile.exists()) {
        await Share.shareXFiles(
          [XFile(cardFile.path, mimeType: 'image/png')],
          text: caption,
        );
        return;
      }
    } catch (_) {}

    await Share.share(caption);
  }
}
