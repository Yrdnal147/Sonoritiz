import 'package:equatable/equatable.dart';
import '../../../../features/player/data/models/track_model.dart';

abstract class DiscoveryState extends Equatable {
  const DiscoveryState();
  
  @override
  List<Object> get props => [];
}

class DiscoveryInitial extends DiscoveryState {}

class DiscoveryLoading extends DiscoveryState {}

class DiscoveryLoaded extends DiscoveryState {
  final List<TrackModel> audioTracks;
  final List<TrackModel> videoTracks;
  final List<TrackModel> lyricsTracks;
  final bool isMuted;

  const DiscoveryLoaded({
    required this.audioTracks,
    required this.videoTracks,
    required this.lyricsTracks,
    this.isMuted = false,
  });

  DiscoveryLoaded copyWith({
    List<TrackModel>? audioTracks,
    List<TrackModel>? videoTracks,
    List<TrackModel>? lyricsTracks,
    bool? isMuted,
  }) {
    return DiscoveryLoaded(
      audioTracks: audioTracks ?? this.audioTracks,
      videoTracks: videoTracks ?? this.videoTracks,
      lyricsTracks: lyricsTracks ?? this.lyricsTracks,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  @override
  List<Object> get props => [audioTracks, videoTracks, lyricsTracks, isMuted];
}

class DiscoveryError extends DiscoveryState {
  final String message;
  const DiscoveryError(this.message);

  @override
  List<Object> get props => [message];
}
