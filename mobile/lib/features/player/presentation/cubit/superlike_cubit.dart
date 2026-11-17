import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/audio/audio_handler.dart';
import '../../../../core/storage/storage_service.dart';
import '../../data/models/track_model.dart';
import 'superlike_state.dart';

class SuperlikeCubit extends Cubit<SuperlikeState> {
  final StorageService _storageService;
  final SonoritizAudioHandler? _audioHandler;
  static const int maxSuperlikes = 20;

  SuperlikeCubit({StorageService? storageService, SonoritizAudioHandler? audioHandler})
      : _storageService = storageService ?? StorageService(),
        _audioHandler = audioHandler,
        super(const SuperlikeState()) {
    loadSuperlikes();
  }

  void reloadForCurrentUser() {
    loadSuperlikes();
  }

  void resetSessionState() {
    emit(const SuperlikeState());
  }

  static bool _isValidSuperlikeId(String rawId) {
    final clean = rawId.trim();
    if (clean.isEmpty) return false;
    const invalid = {'0', 'null', 'undefined', 'deezer_', 'deezer_0', 'deezer_null'};
    return !invalid.contains(clean.toLowerCase());
  }

  void loadSuperlikes() {
    try {
      final rawList = _storageService.getSuperlikesRaw();
      final tracks = rawList
          .map((json) => TrackModel.fromJson(json))
          .where((t) => _isValidSuperlikeId(t.id))
          .toList();
      final ids = tracks.map((t) => t.id.trim()).toSet();
      emit(state.copyWith(
        tracks: tracks,
        superlikedIds: ids,
        isLoaded: true,
      ));
    } catch (_) {
      emit(state.copyWith(isLoaded: true));
    }
  }

  bool isSuperliked(String trackId) {
    final clean = trackId.trim();
    if (!_isValidSuperlikeId(clean)) return false;
    return state.superlikedIds.contains(clean);
  }

  Future<bool> addSuperlike(TrackModel track) async {
    final cleanId = track.id.trim();
    if (!_isValidSuperlikeId(cleanId)) return false;
    if (state.superlikedIds.contains(cleanId)) {
      return true;
    }
    if (state.tracks.length >= maxSuperlikes) {
      return false; // Limit reached, caller must show replacement dialog
    }

    final sanitizedTrack = track.copyWith(id: cleanId);
    final updatedTracks = [sanitizedTrack, ...state.tracks.where((t) => t.id.trim() != cleanId)];
    final updatedIds = updatedTracks.map((t) => t.id.trim()).where((id) => id.isNotEmpty).toSet();
    emit(state.copyWith(tracks: updatedTracks, superlikedIds: updatedIds));
    await _persist();
    if (_audioHandler?.mediaItem.value?.id == cleanId) {
      _audioHandler?.updateReactionState(isFavorite: true, isSuperliked: true);
    }
    return true;
  }

  Future<void> removeSuperlike(String trackId) async {
    final cleanId = trackId.trim();
    if (cleanId.isEmpty) return;
    final updatedTracks = state.tracks.where((t) => t.id.trim() != cleanId).toList();
    final updatedIds = updatedTracks.map((t) => t.id.trim()).where((id) => id.isNotEmpty).toSet();
    emit(state.copyWith(tracks: updatedTracks, superlikedIds: updatedIds));
    await _persist();
    if (_audioHandler?.mediaItem.value?.id == cleanId) {
      _audioHandler?.updateReactionState(isFavorite: true, isSuperliked: false);
    }
  }

  Future<void> replaceSuperlike({
    required TrackModel oldTrack,
    required TrackModel newTrack,
  }) async {
    final updatedTracks = List<TrackModel>.from(state.tracks);
    final index = updatedTracks.indexWhere((t) => t.id == oldTrack.id);
    if (index >= 0) {
      updatedTracks[index] = newTrack;
    } else {
      updatedTracks.removeLast();
      updatedTracks.insert(0, newTrack);
    }
    final updatedIds = updatedTracks.map((t) => t.id).toSet();
    emit(state.copyWith(tracks: updatedTracks, superlikedIds: updatedIds));
    await _persist();
    if (_audioHandler?.mediaItem.value?.id == newTrack.id.trim()) {
      _audioHandler?.updateReactionState(isFavorite: true, isSuperliked: true);
    } else if (_audioHandler?.mediaItem.value?.id == oldTrack.id.trim()) {
      _audioHandler?.updateReactionState(isFavorite: true, isSuperliked: false);
    }
  }

  Future<void> _persist() async {
    final raw = state.tracks.map((t) => t.toJson()).toList();
    await _storageService.saveSuperlikesRaw(raw);
  }
}
