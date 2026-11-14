import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../home/data/repositories/catalog_repository.dart';
import '../../../../features/player/data/models/track_model.dart';
import 'discovery_state.dart';

class DiscoveryCubit extends Cubit<DiscoveryState> {
  final StorageService _storageService;
  final CatalogRepository _catalogRepository;

  DiscoveryCubit({
    required StorageService storageService,
    required CatalogRepository catalogRepository,
  })  : _storageService = storageService,
        _catalogRepository = catalogRepository,
        super(DiscoveryInitial());

  void resetSessionState() {
    emit(DiscoveryInitial());
  }

  Future<void> loadDiscoveryFeeds() async {
    emit(DiscoveryLoading());
    try {
      final recentSearches = _storageService.getSearchHistory();
      final favoriteArtists = _storageService.getFavoriteArtists();

      List<String> keywords = [];
      keywords.addAll(recentSearches.take(3));
      keywords.addAll(favoriteArtists.take(3));

      // Fetch base recommendations
      List<TrackModel> allTracks = [];
      
      // 1. Fetch from trending
      try {
        final trending = await _catalogRepository.getTrendingTracks(limit: 50);
        allTracks.addAll(trending);
      } catch (e) {
        print('Erreur trending fallback: $e');
      }

      // 2. Fetch from a random keyword
      if (keywords.isNotEmpty) {
        keywords.shuffle();
        final kw = keywords.first;
        try {
          final searchResults = await _catalogRepository.yt.search.search('$kw official music video');
          allTracks.addAll(searchResults.whereType<dynamic>().take(20).map((v) => _mapToTrack(v)));
        } catch (e) {
          print('Erreur recherche recommandation $kw: $e');
        }
      } 
      
      // 3. Deduplicate by unique artist
      final Map<String, TrackModel> uniqueArtists = {};
      for (var t in allTracks) {
        String cleanArtist = t.artistName.toLowerCase().trim();
        cleanArtist = cleanArtist.replaceAll('vevo', '').replaceAll('- topic', '').trim();
        
        if (!uniqueArtists.containsKey(cleanArtist)) {
          uniqueArtists[cleanArtist] = t;
        }
      }
      
      List<TrackModel> finalTracks = uniqueArtists.values.toList();
      finalTracks.shuffle();
      
      // We want max 15 per bucket (so 45 total)
      finalTracks = finalTracks.take(45).toList();

      List<TrackModel> audioTracks = [];
      List<TrackModel> videoTracks = [];
      List<TrackModel> lyricsTracks = [];
      
      for (int i = 0; i < finalTracks.length; i++) {
        if (i % 3 == 0) {
          audioTracks.add(finalTracks[i]);
        } else if (i % 3 == 1) {
          videoTracks.add(finalTracks[i]);
        } else {
          lyricsTracks.add(finalTracks[i]);
        }
      }

      emit(DiscoveryLoaded(
        audioTracks: audioTracks,
        videoTracks: videoTracks,
        lyricsTracks: lyricsTracks,
        isMuted: false, // Default mute state
      ));
    } catch (e) {
      emit(DiscoveryError("Impossible de charger les recommandations : $e"));
    }
  }

  void toggleMute() {
    if (state is DiscoveryLoaded) {
      final currentState = state as DiscoveryLoaded;
      emit(currentState.copyWith(isMuted: !currentState.isMuted));
    }
  }

  // Utility to map YouTube Video to TrackModel (simplified)
  TrackModel _mapToTrack(dynamic video) {
    return TrackModel(
      id: video.id.value,
      title: video.title,
      artistName: video.author,
      coverUrl: video.thumbnails.highResUrl,
      audioUrl: '', // Will be fetched later dynamically
      durationSeconds: video.duration?.inSeconds ?? 0,
    );
  }
}
