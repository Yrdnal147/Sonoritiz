import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/lyrics_model.dart';

class LyricsService {
  final Dio _dio;

  LyricsService() : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  String _cleanTitleText(String title, String artist) {
    String cleaned = title;
    // Si le titre contient "Artiste - Titre", retirer le préfixe artiste
    if (cleaned.contains(' - ')) {
      final parts = cleaned.split(' - ');
      if (parts.first.trim().toLowerCase().contains(artist.toLowerCase()) ||
          artist.toLowerCase().contains(parts.first.trim().toLowerCase())) {
        cleaned = parts.sublist(1).join(' - ');
      }
    }
    // Supprimer les mentions entre parenthèses ou crochets (Clip Officiel, Official Video, Lyrics, feat, prod, HD, 4K...)
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*[\(\[][^)\]]*?(official|officiel|clip|lyric|paroles|audio|video|vidéo|visualizer|live|feat|ft\.|prod|hd|4k|hq|version|remix)[^)\]]*?[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    // Supprimer "feat. X" ou "ft. X" en fin de titre sans parenthèses
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+(feat\.?|ft\.?|featuring)\s+.*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*-\s*(topic|vevo|clip officiel|official video|audio).*$', caseSensitive: false),
      '',
    );
    return cleaned.trim();
  }

  String _cleanArtistText(String artist) {
    String cleaned = artist.replaceAll(
      RegExp(r'\s*-\s*topic\s*|\s*vevo\s*|\s*officiel\s*|\s*official\s*', caseSensitive: false),
      '',
    );
    // Garder l'artiste principal si "Artiste A, Artiste B" ou "Artiste A feat. Artiste B"
    cleaned = cleaned.split(RegExp(r'\s+(feat\.?|ft\.?|x|&|,)\s+', caseSensitive: false)).first;
    return cleaned.trim();
  }

  Future<LyricsModel?> getLyrics(String trackId, String artist, String title, int durationSeconds) async {
    final cleanTitle = _cleanTitleText(title, artist);
    final cleanArtist = _cleanArtistText(artist);

    // 1. Si durationSeconds > 0, essayer d'abord la correspondance exacte LRCLIB (/api/get)
    if (durationSeconds > 0) {
      try {
        final response = await _dio.get(
          'https://lrclib.net/api/get',
          queryParameters: {
            'track_name': cleanTitle,
            'artist_name': cleanArtist,
            'duration': durationSeconds,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final model = LyricsModel(
            plainLyrics: data['plainLyrics'] as String?,
            syncedLyrics: data['syncedLyrics'] as String?,
          );
          if (model.hasSynced || model.hasPlain) return model;
        }
      } on DioException catch (_) {}
    }

    // 2. Recherche LRCLIB avec track_name + artist_name (/api/search)
    try {
      final response = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {
          'track_name': cleanTitle,
          'artist_name': cleanArtist,
        },
      );

      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> results = response.data as List<dynamic>;
        if (results.isNotEmpty) {
          // Privilégier un résultat qui possède des paroles synchronisées (syncedLyrics)
          Map<String, dynamic>? bestMatch;
          for (final item in results) {
            if (item is Map<String, dynamic> &&
                item['syncedLyrics'] != null &&
                item['syncedLyrics'].toString().trim().isNotEmpty) {
              bestMatch = item;
              break;
            }
          }
          bestMatch ??= results.first as Map<String, dynamic>;
          final model = LyricsModel(
            plainLyrics: bestMatch['plainLyrics'] as String?,
            syncedLyrics: bestMatch['syncedLyrics'] as String?,
          );
          if (model.hasSynced || model.hasPlain) return model;
        }
      }
    } catch (_) {}

    // 3. Deuxième chance LRCLIB avec requête globale `q` (très efficace quand le titre et l'artiste sont inversés ou combinés)
    try {
      final response = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {
          'q': '$cleanArtist $cleanTitle',
        },
      );

      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> results = response.data as List<dynamic>;
        if (results.isNotEmpty) {
          Map<String, dynamic>? bestMatch;
          for (final item in results) {
            if (item is Map<String, dynamic> &&
                item['syncedLyrics'] != null &&
                item['syncedLyrics'].toString().trim().isNotEmpty) {
              bestMatch = item;
              break;
            }
          }
          bestMatch ??= results.first as Map<String, dynamic>;
          final model = LyricsModel(
            plainLyrics: bestMatch['plainLyrics'] as String?,
            syncedLyrics: bestMatch['syncedLyrics'] as String?,
          );
          if (model.hasSynced || model.hasPlain) return model;
        }
      }
    } catch (_) {}

    // 4. Fallback sur notre backend
    try {
      final baseUrl = ApiConstants.baseUrl;
      final response = await _dio.get('$baseUrl/api/tracks/$trackId/lyrics/');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['lyrics'] != null && data['lyrics'].toString().isNotEmpty) {
          return LyricsModel(plainLyrics: data['lyrics'] as String?);
        }
      }
    } catch (_) {}

    return null;
  }
}
