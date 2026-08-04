import 'package:equatable/equatable.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import '../../data/models/track_model.dart';

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
    bool? isShuffleModeEnabled,
    LoopMode? loopMode,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: errorMessage,
      isShuffleModeEnabled: isShuffleModeEnabled ?? this.isShuffleModeEnabled,
      loopMode: loopMode ?? this.loopMode,
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
      ];
}
