import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/lyrics_model.dart';

class LyricsService {
  final Dio _dio;

  LyricsService() : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  String _cleanText(String input) {
    String cleaned = input.replaceAll(RegExp(r'\s*-\s*topic\s*|\s*vevo\s*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\(.*?(official|lyric|audio|video|visualizer|live).*?\)', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?(official|lyric|audio|video|visualizer|live).*?\]', caseSensitive: false), '');
    return cleaned.trim();
  }

  Future<LyricsModel?> getLyrics(String trackId, String artist, String title, int durationSeconds) async {
    final cleanTitle = _cleanText(title);
    final cleanArtist = _cleanText(artist);

    try {
      // 1. Essayer LRCLIB (meilleure API pour les paroles synchronisées)
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
        return LyricsModel(
          plainLyrics: data['plainLyrics'] as String?,
          syncedLyrics: data['syncedLyrics'] as String?,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        print("Erreur récupération LRCLIB GET: $e");
      }
    }

    try {
      // 2. Si non trouvé (404), utiliser /api/search et prendre le premier résultat
      final response = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {
          'track_name': cleanTitle,
          'artist_name': cleanArtist,
        },
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> results = response.data as List<dynamic>;
        if (results.isNotEmpty) {
          final data = results.first as Map<String, dynamic>;
          return LyricsModel(
            plainLyrics: data['plainLyrics'] as String?,
            syncedLyrics: data['syncedLyrics'] as String?,
          );
        }
      }
    } catch (e) {
      print("Erreur récupération LRCLIB SEARCH: $e");
    }

    try {
      // 3. Fallback sur notre backend
      final baseUrl = ApiConstants.baseUrl;
      final response = await _dio.get('$baseUrl/api/tracks/$trackId/lyrics/');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['lyrics'] != null && data['lyrics'].toString().isNotEmpty) {
          return LyricsModel(plainLyrics: data['lyrics'] as String?);
        }
      }
    } catch (e) {
      print("Erreur récupération lyrics backend: $e");
    }
    
    return null;
  }
}
