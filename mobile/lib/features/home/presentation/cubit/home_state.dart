import 'package:equatable/equatable.dart';
import '../../../player/data/models/track_model.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<TrackModel> trendingTracks;
  final List<TrackModel> newReleases;
  final List<Map<String, String>> genres;

  const HomeLoaded({
    required this.trendingTracks,
    required this.newReleases,
    required this.genres,
  });

  @override
  List<Object?> get props => [trendingTracks, newReleases, genres];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}
