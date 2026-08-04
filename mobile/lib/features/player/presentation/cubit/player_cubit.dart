import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState, LoopMode;
import '../../../../core/audio/audio_handler.dart';
import '../../data/models/track_model.dart';
import 'player_state.dart';

class PlayerCubit extends Cubit<PlayerState> {
  final SonoritizAudioHandler _audioHandler;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  PlayerCubit({required SonoritizAudioHandler audioHandler})
      : _audioHandler = audioHandler,
        super(const PlayerState()) {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _playerStateSubscription = _audioHandler.player.playerStateStream.listen((playerState) {
      emit(state.copyWith(
        isPlaying: playerState.playing,
        isBuffering: playerState.processingState == ProcessingState.buffering ||
            playerState.processingState == ProcessingState.loading,
      ));
    });

    _positionSubscription = _audioHandler.player.positionStream.listen((pos) {
      emit(state.copyWith(position: pos));
    });

    _durationSubscription = _audioHandler.player.durationStream.listen((dur) {
      if (dur != null) {
        emit(state.copyWith(duration: dur));
      }
    });
  }

  Future<void> playTrack(TrackModel track, {List<TrackModel>? queue}) async {
    final currentQueue = queue ?? [track];
    final index = currentQueue.indexWhere((t) => t.id == track.id);
    final targetIndex = index >= 0 ? index : 0;

    emit(state.copyWith(
      queue: currentQueue,
      currentIndex: targetIndex,
      duration: Duration(seconds: track.durationSeconds),
      position: Duration.zero,
    ));

    await _audioHandler.playTrack(track.toMediaItem());
  }

  Future<void> togglePlayPause() async {
    if (!state.hasTrack) return;
    if (state.isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> pause() async {
    if (state.isPlaying) {
      await _audioHandler.pause();
    }
  }

  Future<void> play() async {
    if (!state.isPlaying) {
      await _audioHandler.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  Future<void> playNext() async {
    if (state.queue.isEmpty) return;
    final nextIndex = (state.currentIndex + 1) % state.queue.length;
    final nextTrack = state.queue[nextIndex];
    emit(state.copyWith(currentIndex: nextIndex));
    await _audioHandler.playTrack(nextTrack.toMediaItem());
  }

  Future<void> playPrevious() async {
    if (state.queue.isEmpty) return;
    final prevIndex = (state.currentIndex - 1 + state.queue.length) % state.queue.length;
    final prevTrack = state.queue[prevIndex];
    emit(state.copyWith(currentIndex: prevIndex));
    await _audioHandler.playTrack(prevTrack.toMediaItem());
  }

  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final targetTrack = state.queue[index];
    emit(state.copyWith(currentIndex: index));
    await _audioHandler.playTrack(targetTrack.toMediaItem());
  }

  void addToQueue(TrackModel track) {
    final updatedQueue = List<TrackModel>.from(state.queue)..add(track);
    emit(state.copyWith(queue: updatedQueue));
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final updatedQueue = List<TrackModel>.from(state.queue);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = updatedQueue.removeAt(oldIndex);
    updatedQueue.insert(newIndex, item);

    int newCurrentIndex = state.currentIndex;
    if (oldIndex == state.currentIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < state.currentIndex && newIndex >= state.currentIndex) {
      newCurrentIndex--;
    } else if (oldIndex > state.currentIndex && newIndex <= state.currentIndex) {
      newCurrentIndex++;
    }

    emit(state.copyWith(queue: updatedQueue, currentIndex: newCurrentIndex));
  }

  Future<void> toggleShuffle() async {
    final newShuffleMode = !state.isShuffleModeEnabled;
    emit(state.copyWith(isShuffleModeEnabled: newShuffleMode));
    await _audioHandler.setShuffleModeEnabled(newShuffleMode);
  }

  Future<void> toggleRepeat() async {
    // Cycle : off -> all -> one -> off
    LoopMode nextMode;
    switch (state.loopMode) {
      case LoopMode.off:
        nextMode = LoopMode.all;
        break;
      case LoopMode.all:
        nextMode = LoopMode.one;
        break;
      case LoopMode.one:
        nextMode = LoopMode.off;
        break;
    }
    emit(state.copyWith(loopMode: nextMode));
    await _audioHandler.setLoopMode(nextMode);
  }

  @override
  Future<void> close() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    return super.close();
  }
}
