import 'package:equatable/equatable.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import '../../data/models/track_model.dart';
import '../../data/models/lyrics_model.dart';

class PlayerState extends Equatable {
  final List<TrackModel> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final String? errorMessage;
  final bool isShuffleModeEnabled;
  final LoopMode loopMode;
  final bool isFreeLyricsMode;
  final LyricsModel? currentLyrics;
  final Duration? sleepTimerRemaining;
  final bool isSleepTimerActive;
  final String playbackSource;
  final double vocalAttenuationLevel;
  final Set<String> userQueuedTrackIds;

  const PlayerState({
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
    this.isShuffleModeEnabled = false,
    this.loopMode = LoopMode.off,
    this.isFreeLyricsMode = false,
    this.currentLyrics,
    this.sleepTimerRemaining,
    this.isSleepTimerActive = false,
    this.playbackSource = '',
    this.vocalAttenuationLevel = 0.0,
    this.userQueuedTrackIds = const <String>{},
  });

  TrackModel? get currentTrack {
    if (currentIndex >= 0 && currentIndex < queue.length) {
      return queue[currentIndex];
    }
    return null;
  }

  bool get hasTrack => currentTrack != null;

  PlayerState copyWith({
    List<TrackModel>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
    bool? isShuffleModeEnabled,
    LoopMode? loopMode,
    bool? isFreeLyricsMode,
    LyricsModel? currentLyrics,
    Duration? sleepTimerRemaining,
    bool? isSleepTimerActive,
    String? playbackSource,
    double? vocalAttenuationLevel,
    Set<String>? userQueuedTrackIds,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isShuffleModeEnabled: isShuffleModeEnabled ?? this.isShuffleModeEnabled,
      loopMode: loopMode ?? this.loopMode,
      isFreeLyricsMode: isFreeLyricsMode ?? this.isFreeLyricsMode,
      currentLyrics: currentLyrics ?? this.currentLyrics,
      sleepTimerRemaining: sleepTimerRemaining ?? this.sleepTimerRemaining,
      isSleepTimerActive: isSleepTimerActive ?? this.isSleepTimerActive,
      playbackSource: playbackSource ?? this.playbackSource,
      vocalAttenuationLevel:
          vocalAttenuationLevel ?? this.vocalAttenuationLevel,
      userQueuedTrackIds: userQueuedTrackIds ?? this.userQueuedTrackIds,
    );
  }

  @override
  List<Object?> get props => [
        queue,
        currentIndex,
        isPlaying,
        isBuffering,
        position,
        duration,
        errorMessage,
        isShuffleModeEnabled,
        loopMode,
        isFreeLyricsMode,
        currentLyrics,
        sleepTimerRemaining,
        isSleepTimerActive,
        playbackSource,
        vocalAttenuationLevel,
        userQueuedTrackIds,
      ];
}
