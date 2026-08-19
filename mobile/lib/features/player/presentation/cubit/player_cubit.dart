import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState, LoopMode;
import 'package:home_widget/home_widget.dart';
import '../../../../core/audio/audio_handler.dart';
import '../../../../core/storage/storage_service.dart';
import '../../data/models/lyrics_model.dart';
import '../../data/models/track_model.dart';
import '../../data/services/lyrics_service.dart';
import '../../../library/data/repositories/library_repository.dart';
import 'player_state.dart';

class PlayerCubit extends Cubit<PlayerState> {
  final SonoritizAudioHandler _audioHandler;
  final LyricsService _lyricsService = LyricsService();
  final LibraryRepository? libraryRepository;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  Timer? _sleepTimer;

  PlayerCubit({
    required SonoritizAudioHandler audioHandler,
    this.libraryRepository,
  }) : _audioHandler = audioHandler,
        super(PlayerState(isFreeLyricsMode: StorageService().isFreeLyricsMode)) {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _playerStateSubscription = _audioHandler.player.playerStateStream.listen((playerState) {
      final isCompleted = playerState.processingState == ProcessingState.completed;

      emit(state.copyWith(
        isPlaying: playerState.playing,
        isBuffering: playerState.processingState == ProcessingState.buffering ||
            playerState.processingState == ProcessingState.loading,
      ));

      if (isCompleted) {
        _handleTrackCompleted();
      }
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

  void _handleTrackCompleted() {
    if (state.loopMode == LoopMode.one) {
      _audioHandler.seek(Duration.zero);
      _audioHandler.play();
    } else {
      if (state.currentIndex < state.queue.length - 1) {
        playNext();
      } else {
        if (state.loopMode == LoopMode.all) {
          playNext(); // Wraps around automatically
        } else {
          _audioHandler.pause();
          _audioHandler.seek(Duration.zero);
          emit(state.copyWith(isPlaying: false));
        }
      }
    }
  }

  Future<void> _updateHomeWidget(TrackModel track) async {
    try {
      await HomeWidget.saveWidgetData<String>('title', track.title);
      await HomeWidget.saveWidgetData<String>('artist', track.artistName);
      
      final isFav = await libraryRepository?.isFavorite(track.id) ?? false;
      await HomeWidget.saveWidgetData<bool>('isFavorite', isFav);
      
      if (track.coverUrl.isNotEmpty) {
        try {
          final tempDir = await getTemporaryDirectory();
          final uri = Uri.parse(track.coverUrl);
          String ext = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.split('.').last : 'jpg';
          if (!['jpg', 'jpeg', 'png'].contains(ext.toLowerCase())) ext = 'jpg';
          final localPath = '${tempDir.path}/widget_cover_${track.id}.$ext';
          final file = File(localPath);
          if (!await file.exists()) {
            final dio = Dio();
            await dio.download(track.coverUrl, localPath);
          }
          await HomeWidget.saveWidgetData<String>('coverPath', localPath);
        } catch (e) {
          await HomeWidget.saveWidgetData<String>('coverPath', null);
        }
      } else {
        await HomeWidget.saveWidgetData<String>('coverPath', null);
      }

      // --- Download history covers for the large widget ---
      try {
        final historyList = await libraryRepository?.getHistory() ?? [];
        final coversList = <TrackModel>[];
        final seenUrls = <String>[];
        for (var item in historyList) {
           if (item.track != null && item.track!.coverUrl.isNotEmpty && !seenUrls.contains(item.track!.coverUrl)) {
               seenUrls.add(item.track!.coverUrl);
               coversList.add(item.track!);
           }
           if (coversList.length >= 5) break;
        }
        
        final tempDir = await getTemporaryDirectory();
        final dio = Dio();
        for (int i = 0; i < 5; i++) {
           if (i < coversList.length) {
              final track = coversList[i];
              final url = track.coverUrl;
              final uri = Uri.parse(url);
              String ext = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.split('.').last : 'jpg';
              if (!['jpg', 'jpeg', 'png'].contains(ext.toLowerCase())) ext = 'jpg';
              final localPath = '${tempDir.path}/widget_hist_$i.$ext';
              final file = File(localPath);
              if (!await file.exists()) {
                 await dio.download(url, localPath);
              }
              await HomeWidget.saveWidgetData<String>('hist_cover_$i', localPath);
              await HomeWidget.saveWidgetData<String>('hist_title_$i', coversList[i].title);
              await HomeWidget.saveWidgetData<String>('hist_artist_$i', coversList[i].artistName);
           } else {
              await HomeWidget.saveWidgetData<String>('hist_cover_$i', null);
              await HomeWidget.saveWidgetData<String>('hist_title_$i', null);
              await HomeWidget.saveWidgetData<String>('hist_artist_$i', null);
           }
        }
      } catch (e) {
        // Ignore history fetch errors
      }

      await HomeWidget.updateWidget(androidName: 'NowPlayingWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'PlaylistWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'MiniSquareWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'RecentListWidgetProvider');
    } catch (e) {
      // Ignorer l'erreur si le widget n'est pas encore prêt
    }
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

    _updateHomeWidget(track);
    libraryRepository?.addToHistory(track);
    await _audioHandler.playTrack(track.toMediaItem());
    _fetchLyrics(track);
  }

  Future<void> _fetchLyrics(TrackModel track) async {
    // Optional: Only fetch if in free lyrics mode? Let's always fetch so it's ready.
    emit(state.copyWith(currentLyrics: LyricsModel(plainLyrics: '', syncedLyrics: '')));
    try {
      final lyrics = await _lyricsService.getLyrics(track.id, track.artistName, track.title, track.durationSeconds);
      if (state.currentTrack?.id == track.id) {
        emit(state.copyWith(currentLyrics: lyrics));
      }
    } catch (_) {}
  }

  void toggleFreeLyricsMode() {
    final newValue = !state.isFreeLyricsMode;
    StorageService().setFreeLyricsMode(newValue);
    emit(state.copyWith(isFreeLyricsMode: newValue));
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
    int nextIndex;
    if (state.isShuffleModeEnabled && state.queue.length > 1) {
      nextIndex = state.currentIndex;
      while (nextIndex == state.currentIndex) {
        nextIndex = Random().nextInt(state.queue.length);
      }
    } else {
      nextIndex = (state.currentIndex + 1) % state.queue.length;
    }
    final nextTrack = state.queue[nextIndex];
    emit(state.copyWith(currentIndex: nextIndex));
    _updateHomeWidget(nextTrack);
    await _audioHandler.playTrack(nextTrack.toMediaItem());
    _fetchLyrics(nextTrack);
  }

  Future<void> playPrevious() async {
    if (state.queue.isEmpty) return;
    int prevIndex;
    if (state.isShuffleModeEnabled && state.queue.length > 1) {
      prevIndex = state.currentIndex;
      while (prevIndex == state.currentIndex) {
        prevIndex = Random().nextInt(state.queue.length);
      }
    } else {
      prevIndex = (state.currentIndex - 1 + state.queue.length) % state.queue.length;
    }
    final prevTrack = state.queue[prevIndex];
    emit(state.copyWith(currentIndex: prevIndex));
    _updateHomeWidget(prevTrack);
    await _audioHandler.playTrack(prevTrack.toMediaItem());
    _fetchLyrics(prevTrack);
  }

  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final targetTrack = state.queue[index];
    emit(state.copyWith(currentIndex: index));
    _updateHomeWidget(targetTrack);
    await _audioHandler.playTrack(targetTrack.toMediaItem());
    _fetchLyrics(targetTrack);
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
    _sleepTimer?.cancel();
    return super.close();
  }

  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    emit(state.copyWith(
      isSleepTimerActive: true,
      sleepTimerRemaining: duration,
    ));

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.sleepTimerRemaining == null) return;
      
      final remaining = state.sleepTimerRemaining! - const Duration(seconds: 1);
      
      if (remaining.inSeconds <= 0) {
        cancelSleepTimer();
        _audioHandler.pause();
      } else {
        emit(state.copyWith(sleepTimerRemaining: remaining));
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    emit(state.copyWith(
      isSleepTimerActive: false,
      sleepTimerRemaining: Duration.zero,
    ));
  }
}
