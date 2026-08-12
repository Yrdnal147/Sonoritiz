import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart' as dio_pkg;
import '../../../../core/network/api_client.dart';
import '../../../player/data/models/track_model.dart';

class CatalogRepository {
  final ApiClient apiClient;
  final YoutubeExplode yt = YoutubeExplode();

  CatalogRepository({required this.apiClient});

  // 1. Tendances globales (sans filtre de date)
  Future<List<TrackModel>> getTrendingTracks({int limit = 20, int offset = 0}) async {
    try {
      final searchResults = await yt.search.search('top hits 2026 musique officielle');
      final videos = searchResults.whereType<Video>().take(limit).toList();
      return videos.map((v) => _mapVideoToTrack(v)).toList();
    } catch (e) {
      print('getTrendingTracks error: $e');
      return [];
    }
  }

  // 2. Tendances récentes (Nouveautés des 3 derniers mois approx)
  Future<List<TrackModel>> getRecentTrends({int limit = 50}) async {
    try {
      // Pour simuler des nouveautés récentes, on cherche "nouveauté musique 2026"
      final searchResults = await yt.search.search('nouveauté musique 2026 official clip');
      final videos = searchResults.whereType<Video>().take(limit).toList();
      
      // On pourrait filtrer par date si l'uploadDate était toujours précis via l'API, 
      // mais la recherche Youtube avec ces mots-clés est plus fiable.
      return videos.map((v) => _mapVideoToTrack(v)).toList();
    } catch (e) {
      print('getRecentTrends error: $e');
      return [];
    }
  }

  // 3. Top Artistes (Récupération dynamique basée sur les sons populaires)
  Future<List<String>> getTopArtists({int limit = 20}) async {
    try {
      final searchResults = await yt.search.search('artistes les plus écoutés monde officiel');
      final videos = searchResults.whereType<Video>().take(limit * 2).toList();
      
      final Set<String> artists = {};
      for (var v in videos) {
        if (v.author.isNotEmpty && !v.author.toLowerCase().contains("vevo")) {
          artists.add(v.author);
        } else if (v.author.toLowerCase().contains("vevo")) {
          artists.add(v.author.replaceAll(RegExp(r'VEVO', caseSensitive: false), ''));
        }
      }
      return artists.take(limit).toList();
    } catch (e) {
      print('getTopArtists error: $e');
      return [];
    }
  }

  // 4. Meilleurs sons d'un artiste
  Future<List<TrackModel>> getArtistTopTracks(String artistName, {int limit = 20}) async {
    try {
      final searchResults = await yt.search.search('$artistName official music video');
      final videos = searchResults.whereType<Video>().take(limit).toList();
      return videos.map((v) => _mapVideoToTrack(v)).toList();
    } catch (e) {
      print('getArtistTopTracks error: $e');
      return [];
    }
  }

  // 5. Recommandations basées sur des artistes favoris
  Future<List<TrackModel>> getRecommendations(List<String> favoriteArtists, {int limit = 15}) async {
    if (favoriteArtists.isEmpty) {
      // Recommandations par défaut
      return getTrendingTracks(limit: limit);
    }
    
    try {
      List<TrackModel> results = [];
      // On prend jusqu'à 3 artistes au hasard parmi les favoris pour varier
      favoriteArtists.shuffle();
      final selectedArtists = favoriteArtists.take(3);
      
      for (String artist in selectedArtists) {
        final searchResults = await yt.search.search('$artist mix similar artists official');
        final videos = searchResults.whereType<Video>().take(limit ~/ selectedArtists.length).toList();
        results.addAll(videos.map((v) => _mapVideoToTrack(v)));
      }
      results.shuffle();
      return results;
    } catch (e) {
      print('getRecommendations error: $e');
      return [];
    }
  }

  // 6. Quiz Musical
  Future<List<TrackModel>> getQuizTracks({int limit = 20}) async {
    try {
      // Pour avoir une bonne variété, on cherche un mix officiel
      final searchResults = await yt.search.search('top hits musique officiel');
      final videos = searchResults.whereType<Video>().take(limit * 2).toList();
      videos.shuffle(); // Mélanger pour plus d'aléatoire
      return videos.take(limit).map((v) => _mapVideoToTrack(v)).toList();
    } catch (e) {
      print('getQuizTracks error: $e');
      return [];
    }
  }

  // 7. Podcasts
  Future<List<TrackModel>> getPodcasts({String query = '', int limit = 20}) async {
    try {
      final searchQuery = query.isEmpty ? 'podcast complet français officiel' : '$query podcast officiel complet';
      final searchResults = await yt.search.search(searchQuery);
      final videos = searchResults.whereType<Video>().take(limit).toList();
      return videos.map((v) => _mapVideoToTrack(v)).toList();
    } catch (e) {
      print('getPodcasts error: $e');
      return [];
    }
  }

  Future<List<TrackModel>> searchTracks({String query = '', String genre = '', int limit = 50, int offset = 0}) async {
    try {
      final searchQuery = genre.isNotEmpty ? '$query $genre official music' : '$query official music';
      final searchResults = await yt.search.search(searchQuery);
      final videos = searchResults.whereType<Video>().take(limit).toList();
      return videos.map((v) => _mapVideoToTrack(v)).toList();
    } catch (e) {
      print('searchTracks error: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> getGenres() async {
    return [
      {'id': 'rap', 'name': 'Rap'},
      {'id': 'pop', 'name': 'Pop'},
      {'id': 'rnb', 'name': 'R&B'},
      {'id': 'rock', 'name': 'Rock'},
      {'id': 'electro', 'name': 'Electro'},
      {'id': 'afrobeat', 'name': 'Afrobeat'},
      {'id': 'jazz', 'name': 'Jazz'},
      {'id': 'lofi', 'name': 'Lo-Fi'},
    ];
  }

  Future<String> getArtistBio(String artistName) async {
    try {
      final dioClient = dio_pkg.Dio();
      final url = 'https://fr.wikipedia.org/w/api.php?action=query&prop=extracts&exintro=1&explaintext=1&titles=${Uri.encodeComponent(artistName)}&format=json';
      final response = await dioClient.get(url);
      
      if (response.statusCode == 200) {
        final data = response.data;
        final pages = data['query']['pages'] as Map<String, dynamic>;
        if (pages.isNotEmpty) {
          final firstPage = pages.values.first;
          if (firstPage.containsKey('extract') && firstPage['extract'] != null) {
            final extract = firstPage['extract'] as String;
            if (extract.isNotEmpty && !extract.contains("peut faire référence à")) {
              return extract; 
            }
          }
        }
      }
    } catch (e) {
      print('getArtistBio error: $e');
    }
    
    return "Découvrez les meilleurs titres et les nouveautés de $artistName sur Sonoritiz. Retrouvez ses plus grands succès et ses dernières sorties.";
  }

  TrackModel _mapVideoToTrack(Video video) {
    return TrackModel(
      id: video.id.value,
      title: video.title,
      artistName: video.author,
      albumName: 'YouTube Audio',
      coverUrl: video.thumbnails.highResUrl,
      durationSeconds: video.duration?.inSeconds ?? 0,
      audioUrl: '', // URL résolue à la lecture
      genre: 'YouTube',
      licenseCcUrl: '',
    );
  }
}
