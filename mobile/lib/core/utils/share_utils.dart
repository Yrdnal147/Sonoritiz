import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Color;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../storage/storage_service.dart';
import '../../features/player/data/models/track_model.dart';
import 'share_card_generator.dart';

class ShareUtils {
  /// Formate un message texte WhatsApp avec typographie markdown, emojis et séparateurs élégants.
  static String formatShareText(TrackModel track, {bool isSuperliked = false}) {
    final durationStr = track.durationSeconds > 0
        ? "${(track.durationSeconds ~/ 60).toString().padLeft(2, '0')}:${(track.durationSeconds % 60).toString().padLeft(2, '0')}"
        : null;

    final buffer = StringBuffer();
    buffer.writeln(isSuperliked ? "⭐ *Sonoritiz Superlike*" : "✨ *Sonoritiz Music*");
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
    buffer.writeln("🎧 Écoute ce chef-d'œuvre en haute qualité sur Sonoritiz :");
    buffer.writeln("👉 https://sonoritiz.com/track/${track.id}");
    buffer.writeln("━━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("🔥 _Vibre au rythme de tes sons préférés_");
    return buffer.toString();
  }

  /// Partage un morceau avec une carte visuelle HD stylée (type Story) et un texte WhatsApp soigné.
  static Future<void> shareTrack(TrackModel track) async {
    final bool isSuperliked = StorageService()
        .getSuperlikesRaw()
        .any((item) => item['id']?.toString() == track.id);

    final text = formatShareText(track, isSuperliked: isSuperliked);

    if (track.coverUrl.isEmpty) {
      await Share.share(text);
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();

      final uri = Uri.parse(track.coverUrl);
      String ext = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.split('.').last : 'jpg';
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
        } else if (track.coverUrl.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(track.coverUrl)) {
          final rawFile = File(track.coverUrl);
          if (await rawFile.exists()) {
            await rawFile.copy(localPath);
          }
        } else {
          final dio = Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 15),
          ));
          await dio.download(track.coverUrl, localPath);
        }
      }

      // 1. Tenter de générer la Carte de Partage Sonoritiz Premium
      if (await file.exists()) {
        final cardFile = await ShareCardGenerator.generateShareCard(
          track: track,
          coverFile: file,
          isSuperliked: isSuperliked,
        );

        if (cardFile != null && await cardFile.exists()) {
          final xFile = XFile(cardFile.path, mimeType: 'image/png');
          await Share.shareXFiles([xFile], text: text);
          return;
        }

        // Fallback: partager la pochette d'origine si la génération échoue
        final xFile = XFile(file.path);
        await Share.shareXFiles([xFile], text: text);
        return;
      }

      await Share.share(text);
    } catch (e) {
      await Share.share(text);
    }
  }

  /// Génère et partage une Carte Visuelle de Paroles (« Sonoritiz Lyric Card ») avec le logo transparent.
  static Future<void> shareLyricsCard({
    required TrackModel track,
    required List<String> lyricLines,
    required Color dominantColor,
    required Color deepColor,
    required Color accentColor,
  }) async {
    final cleanedLines =
        lyricLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final quoteBlock =
        cleanedLines.map((l) => '“$l”').join('\n');
    final caption =
        "$quoteBlock\n\n🎵 *${track.title}* — ${track.artistName}\n✨ Partagé via *Sonoritiz Lyrics*";

    try {
      File? coverFile;
      if (track.coverUrl.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final safeId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final localPath = '${tempDir.path}/share_raw_$safeId.jpg';
        final candidate = File(localPath);
        if (!await candidate.exists() || await candidate.length() < 512) {
          if (track.coverUrl.startsWith('file://')) {
            final rawFile = File(track.coverUrl.replaceFirst('file://', ''));
            if (await rawFile.exists()) {
              await rawFile.copy(localPath);
            }
          } else if (track.coverUrl.startsWith('http')) {
            final dio = Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
            ));
            await dio.download(track.coverUrl, localPath);
          }
        }
        if (await candidate.exists()) {
          coverFile = candidate;
        }
      }

      final cardFile = await ShareCardGenerator.generateLyricsShareCard(
        track: track,
        lyricLines: cleanedLines,
        coverFile: coverFile,
        dominantColor: dominantColor,
        deepColor: deepColor,
        accentColor: accentColor,
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
