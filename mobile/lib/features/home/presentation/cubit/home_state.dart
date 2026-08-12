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
  final List<TrackModel> trendingTracks;
  final List<TrackModel> recentTrends;
  final List<TrackModel> recommendations;
  final List<TrackModel> podcastTracks;
  final List<String> topArtists;
  final List<Map<String, String>> favoriteArtists;
  final List<PlaylistModel> userPlaylists;
  final List<TrackModel> userFavorites;
  final List<Map<String, String>> genres;

  const HomeLoaded({
    required this.trendingTracks,
    required this.recentTrends,
    required this.recommendations,
    required this.podcastTracks,
    required this.topArtists,
    required this.favoriteArtists,
    required this.userPlaylists,
    required this.userFavorites,
    required this.genres,
  });

  @override
  List<Object?> get props => [
        trendingTracks,
        recentTrends,
        recommendations,
        podcastTracks,
        topArtists,
        favoriteArtists,
        userPlaylists,
        userFavorites,
        genres,
      ];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}
