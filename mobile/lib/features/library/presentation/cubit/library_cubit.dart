import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/library_repository.dart';
import '../../../player/data/models/track_model.dart';
import 'library_state.dart';

class LibraryCubit extends Cubit<LibraryState> {
  final LibraryRepository repository;

  LibraryCubit({required this.repository}) : super(LibraryInitial());

  Future<void> loadLibraryData() async {
    emit(LibraryLoading());
    try {
      final favorites = await repository.getFavorites();
      final playlists = await repository.getPlaylists();
      final history = await repository.getHistory();

      emit(LibraryLoaded(
        favorites: favorites,
        playlists: playlists,
        history: history,
      ));
    } catch (e, stack) {
      print("Erreur complète: $e\n$stack");
      emit(LibraryError("Une erreur est survenue lors du chargement de votre bibliothèque.\n\nDétail: $e"));
    }
  }

  Future<void> createPlaylist(String name) async {
    try {
      await repository.createPlaylist(name);
      await loadLibraryData();
    } catch (_) {}
  }

  Future<void> addTrackToPlaylist(int playlistId, TrackModel track) async {
    try {
      await repository.addTrackToPlaylist(playlistId, track);
      await loadLibraryData();
    } catch (e) {
      print("Erreur addTrackToPlaylist: $e");
    }
  }

  Future<void> addFavorite(TrackModel track) async {
    try {
      await repository.addFavorite(track);
      await loadLibraryData(); // Refresh the list
    } catch (_) {}
  }

  Future<void> removeFavorite(String trackId) async {
    try {
      await repository.removeFavorite(trackId);
      await loadLibraryData();
    } catch (_) {}
  }

  bool isFavorite(String trackId) {
    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      return loadedState.favorites.any((track) => track.id == trackId);
    }
    return false;
  }
}
