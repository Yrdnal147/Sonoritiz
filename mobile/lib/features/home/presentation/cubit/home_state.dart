import 'package:equatable/equatable.dart';
import '../../../player/data/models/track_model.dart';
import '../../../library/data/repositories/library_repository.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final String contextualGreeting;
  final List<TrackModel> contextualTracks;
  final Map<String, List<TrackModel>> dailyMixes;
  final String? similarToArtistName;
  final List<TrackModel> similarToArtistTracks;
  
  final List<TrackModel> newReleases;
  final List<TrackModel> trendingTracks;
  final List<TrackModel> recentTrends;
  final List<TrackModel> recommendations;
  final List<TrackModel> podcastTracks;
  final List<Map<String, String>> topArtists;
  final List<Map<String, String>> favoriteArtists;
  final List<PlaylistModel> userPlaylists;
  final List<TrackModel> userFavorites;
  final List<Map<String, String>> genres;
  final List<Map<String, dynamic>> editorialPlaylists;
  final String selectedMood;
  final List<TrackModel> moodTracks;
  final bool isFilteringMood;
  final bool isMoodLoading;

  final List<TrackModel> afrobeatsTracks;
  final List<TrackModel> cameroonTracks;
  final List<TrackModel> topUsaTracks;
  final Map<String, List<TrackModel>> continentalCharts;
  final String selectedContinent;
  final bool isContinentLoading;

  final List<TrackModel> recentlyPlayed;
  final List<Map<String, dynamic>> weeklyCuratedPlaylists;
  final List<TrackModel> sonoritizRandomTracks;
  final List<Map<String, dynamic>> upcomingReleases;
  final bool hasAfroAffinity;
  final bool hasUsPopAffinity;

  const HomeLoaded({
    required this.contextualGreeting,
    required this.contextualTracks,
    required this.dailyMixes,
    this.similarToArtistName,
    this.similarToArtistTracks = const [],
    required this.newReleases,
    required this.trendingTracks,
    required this.recentTrends,
    required this.recommendations,
    required this.podcastTracks,
    required this.topArtists,
    required this.favoriteArtists,
    required this.userPlaylists,
    required this.userFavorites,
    required this.genres,
    this.editorialPlaylists = const [],
    this.selectedMood = 'detente',
    this.moodTracks = const [],
    this.isFilteringMood = false,
    this.isMoodLoading = false,
    this.afrobeatsTracks = const [],
    this.cameroonTracks = const [],
    this.topUsaTracks = const [],
    this.continentalCharts = const {},
    this.selectedContinent = 'africa',
    this.isContinentLoading = false,
    this.recentlyPlayed = const [],
    this.weeklyCuratedPlaylists = const [],
    this.sonoritizRandomTracks = const [],
    this.upcomingReleases = const [],
    this.hasAfroAffinity = true,
    this.hasUsPopAffinity = true,
  });

  HomeLoaded copyWith({
    String? contextualGreeting,
    List<TrackModel>? contextualTracks,
    Map<String, List<TrackModel>>? dailyMixes,
    String? similarToArtistName,
    List<TrackModel>? similarToArtistTracks,
    List<TrackModel>? newReleases,
    List<TrackModel>? trendingTracks,
    List<TrackModel>? recentTrends,
    List<TrackModel>? recommendations,
    List<TrackModel>? podcastTracks,
    List<Map<String, String>>? topArtists,
    List<Map<String, String>>? favoriteArtists,
    List<PlaylistModel>? userPlaylists,
    List<TrackModel>? userFavorites,
    List<Map<String, String>>? genres,
    List<Map<String, dynamic>>? editorialPlaylists,
    String? selectedMood,
    List<TrackModel>? moodTracks,
    bool? isFilteringMood,
    bool? isMoodLoading,
    List<TrackModel>? afrobeatsTracks,
    List<TrackModel>? cameroonTracks,
    List<TrackModel>? topUsaTracks,
    Map<String, List<TrackModel>>? continentalCharts,
    String? selectedContinent,
    bool? isContinentLoading,
    List<TrackModel>? recentlyPlayed,
    List<Map<String, dynamic>>? weeklyCuratedPlaylists,
    List<TrackModel>? sonoritizRandomTracks,
    List<Map<String, dynamic>>? upcomingReleases,
    bool? hasAfroAffinity,
    bool? hasUsPopAffinity,
  }) {
    return HomeLoaded(
      contextualGreeting: contextualGreeting ?? this.contextualGreeting,
      contextualTracks: contextualTracks ?? this.contextualTracks,
      dailyMixes: dailyMixes ?? this.dailyMixes,
      similarToArtistName: similarToArtistName ?? this.similarToArtistName,
      similarToArtistTracks: similarToArtistTracks ?? this.similarToArtistTracks,
      newReleases: newReleases ?? this.newReleases,
      trendingTracks: trendingTracks ?? this.trendingTracks,
      recentTrends: recentTrends ?? this.recentTrends,
      recommendations: recommendations ?? this.recommendations,
      podcastTracks: podcastTracks ?? this.podcastTracks,
      topArtists: topArtists ?? this.topArtists,
      favoriteArtists: favoriteArtists ?? this.favoriteArtists,
      userPlaylists: userPlaylists ?? this.userPlaylists,
      userFavorites: userFavorites ?? this.userFavorites,
      genres: genres ?? this.genres,
      editorialPlaylists: editorialPlaylists ?? this.editorialPlaylists,
      selectedMood: selectedMood ?? this.selectedMood,
      moodTracks: moodTracks ?? this.moodTracks,
      isFilteringMood: isFilteringMood ?? this.isFilteringMood,
      isMoodLoading: isMoodLoading ?? this.isMoodLoading,
      afrobeatsTracks: afrobeatsTracks ?? this.afrobeatsTracks,
      cameroonTracks: cameroonTracks ?? this.cameroonTracks,
      topUsaTracks: topUsaTracks ?? this.topUsaTracks,
      continentalCharts: continentalCharts ?? this.continentalCharts,
      selectedContinent: selectedContinent ?? this.selectedContinent,
      isContinentLoading: isContinentLoading ?? this.isContinentLoading,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      weeklyCuratedPlaylists: weeklyCuratedPlaylists ?? this.weeklyCuratedPlaylists,
      sonoritizRandomTracks: sonoritizRandomTracks ?? this.sonoritizRandomTracks,
      upcomingReleases: upcomingReleases ?? this.upcomingReleases,
      hasAfroAffinity: hasAfroAffinity ?? this.hasAfroAffinity,
      hasUsPopAffinity: hasUsPopAffinity ?? this.hasUsPopAffinity,
    );
  }

  @override
  List<Object?> get props => [
        contextualGreeting,
        contextualTracks,
        dailyMixes,
        similarToArtistName,
        similarToArtistTracks,
        newReleases,
        trendingTracks,
        recentTrends,
        recommendations,
        podcastTracks,
        topArtists,
        favoriteArtists,
        userPlaylists,
        userFavorites,
        genres,
        editorialPlaylists,
        selectedMood,
        moodTracks,
        isFilteringMood,
        isMoodLoading,
        afrobeatsTracks,
        cameroonTracks,
        topUsaTracks,
        continentalCharts,
        selectedContinent,
        isContinentLoading,
        recentlyPlayed,
        weeklyCuratedPlaylists,
        sonoritizRandomTracks,
        upcomingReleases,
        hasAfroAffinity,
        hasUsPopAffinity,
      ];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}
