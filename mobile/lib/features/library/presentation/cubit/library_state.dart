import 'package:equatable/equatable.dart';
import '../../../player/data/models/track_model.dart';
import '../../data/repositories/library_repository.dart';

abstract class LibraryState extends Equatable {
  const LibraryState();

  @override
  List<Object?> get props => [];
}

class LibraryInitial extends LibraryState {}

class LibraryLoading extends LibraryState {}

class LibraryLoaded extends LibraryState {
  final List<TrackModel> favorites;
  final List<PlaylistModel> playlists;
  final List<HistoryModel> history;

  const LibraryLoaded({
    required this.favorites,
    required this.playlists,
    required this.history,
  });

  @override
  List<Object?> get props => [favorites, playlists, history];
}

class LibraryError extends LibraryState {
  final String message;

  const LibraryError(this.message);

  @override
  List<Object?> get props => [message];
}
