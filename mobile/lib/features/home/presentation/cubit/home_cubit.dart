import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/storage_service.dart' show StorageService;
import '../../../../core/constants/artists_data.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../../library/data/repositories/library_repository.dart';
import '../../../player/data/models/track_model.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final CatalogRepository catalogRepository;
  final LibraryRepository libraryRepository;
  final StorageService storageService;

  HomeCubit({
    required this.catalogRepository,
    required this.libraryRepository,
    required this.storageService,
  }) : super(HomeInitial());

  Future<void> loadHomeData() async {
    emit(HomeLoading());
    try {
      // Parallélisation massive pour accélérer le chargement
      final results = await Future.wait([
        catalogRepository.getGenres(), // 0
        catalogRepository.getTrendingTracks(limit: 15), // 1
        catalogRepository.getRecentTrends(limit: 15), // 2
        catalogRepository.getPodcasts(limit: 10), // 3
        catalogRepository.getTopArtists(limit: 20), // 4
        libraryRepository.getFavorites(), // 5
        libraryRepository.getPlaylists(), // 6
      ]);

      final genres = results[0] as List<Map<String, String>>;
      final trendingTracks = results[1] as List<TrackModel>;
      final recentTrends = results[2] as List<TrackModel>;
      final podcastTracks = results[3] as List<TrackModel>;
      final topArtists = results[4] as List<String>;
      final userFavorites = results[5] as List<TrackModel>;
      final userPlaylists = results[6] as List<PlaylistModel>;

      // Artistes favoris de l'utilisateur (noms)
      final favoriteArtistNames = storageService.getFavoriteArtists();
      
      // On récupère les infos complètes (nom + image) depuis ArtistsData
      final favoriteArtists = favoriteArtistNames.map((name) {
        return ArtistsData.globalArtists.firstWhere(
          (a) => a['name'] == name,
          orElse: () => {'name': name, 'imageUrl': ''},
        );
      }).toList();
      
      // Recommandations (dépend de favoriteArtistNames, on peut le lancer en parallèle avec le reste idéalement, mais on le garde ici car rapide)
      final recommendations = await catalogRepository.getRecommendations(favoriteArtistNames, limit: 15);

      if (isClosed) return;
      emit(HomeLoaded(
        trendingTracks: trendingTracks,
        recentTrends: recentTrends,
        recommendations: recommendations,
        podcastTracks: podcastTracks,
        topArtists: topArtists,
        favoriteArtists: favoriteArtists,
        userPlaylists: userPlaylists,
        userFavorites: userFavorites,
        genres: genres,
      ));
    } catch (e, stack) {
      if (isClosed) return;
      print('=== ERREUR HOME CUBIT ===');
      print(e);
      print(stack);
      emit(HomeError("Impossible de charger les données de l'accueil."));
    }
  }

  Future<void> saveFavoriteArtists(List<String> artists) async {
    await storageService.saveFavoriteArtists(artists);
    
    if (state is HomeLoaded) {
      final currentState = state as HomeLoaded;
      
      // Récupérer les nouveaux favoris avec leurs images
      final favoriteArtists = artists.map((name) {
        return ArtistsData.globalArtists.firstWhere(
          (a) => a['name'] == name,
          orElse: () => {'name': name, 'imageUrl': ''},
        );
      }).toList();
      
      // On met à jour l'état actuel avec les nouveaux favoris (sans recharger le reste)
      emit(HomeLoaded(
        trendingTracks: currentState.trendingTracks,
        recentTrends: currentState.recentTrends,
        recommendations: currentState.recommendations, // On garde l'ancien le temps de charger
        podcastTracks: currentState.podcastTracks,
        topArtists: currentState.topArtists,
        favoriteArtists: favoriteArtists,
        userPlaylists: currentState.userPlaylists,
        userFavorites: currentState.userFavorites,
        genres: currentState.genres,
      ));

      // Charger les nouvelles recos discrètement en arrière-plan
      try {
        final newRecommendations = await catalogRepository.getRecommendations(artists, limit: 15);
        if (isClosed) return;
        emit(HomeLoaded(
          trendingTracks: currentState.trendingTracks,
          recentTrends: currentState.recentTrends,
          recommendations: newRecommendations,
          podcastTracks: currentState.podcastTracks,
          topArtists: currentState.topArtists,
          favoriteArtists: favoriteArtists,
          userPlaylists: currentState.userPlaylists,
          userFavorites: currentState.userFavorites,
          genres: currentState.genres,
        ));
      } catch (_) {
        // Ignorer l'erreur, on garde les anciennes recos
      }
    } else {
      loadHomeData(); // Fallback si l'état n'était pas chargé
    }
  }
}
