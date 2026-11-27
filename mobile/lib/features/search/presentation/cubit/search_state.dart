import 'package:equatable/equatable.dart';
import '../../../player/data/models/track_model.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {
  final List<String> recentSearches;

  const SearchInitial({required this.recentSearches});

  @override
  List<Object?> get props => [recentSearches];
}

class SearchLoading extends SearchState {}

class SearchSuccess extends SearchState {
  final List<TrackModel> results;
  final List<Map<String, dynamic>> artists;
  final List<Map<String, dynamic>> albums;
  final String query;

  const SearchSuccess({
    required this.results,
    required this.artists,
    this.albums = const [],
    required this.query,
  });

  @override
  List<Object?> get props => [results, artists, albums, query];
}

class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  List<Object?> get props => [message];
}
