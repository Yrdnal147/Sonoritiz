import 'package:equatable/equatable.dart';
import '../../data/models/track_model.dart';

class SuperlikeState extends Equatable {
  final List<TrackModel> tracks;
  final Set<String> superlikedIds;
  final bool isLoaded;

  const SuperlikeState({
    this.tracks = const [],
    this.superlikedIds = const {},
    this.isLoaded = false,
  });

  bool isSuperliked(String trackId) {
    final clean = trackId.trim();
    if (clean.isEmpty) return false;
    return superlikedIds.contains(clean);
  }

  SuperlikeState copyWith({
    List<TrackModel>? tracks,
    Set<String>? superlikedIds,
    bool? isLoaded,
  }) {
    return SuperlikeState(
      tracks: tracks ?? this.tracks,
      superlikedIds: superlikedIds ?? this.superlikedIds,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  @override
  List<Object?> get props => [tracks, superlikedIds, isLoaded];
}
