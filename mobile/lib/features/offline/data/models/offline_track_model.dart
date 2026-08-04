import '../../../player/data/models/track_model.dart';

class OfflineTrackModel {
  final TrackModel track;
  final String localAudioPath;
  final String localCoverPath;
  final DateTime downloadedAt;

  OfflineTrackModel({
    required this.track,
    required this.localAudioPath,
    required this.localCoverPath,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'track': track.toJson(),
      'localAudioPath': localAudioPath,
      'localCoverPath': localCoverPath,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }

  factory OfflineTrackModel.fromJson(Map<String, dynamic> json) {
    return OfflineTrackModel(
      track: TrackModel.fromJson(json['track']),
      localAudioPath: json['localAudioPath'] ?? '',
      localCoverPath: json['localCoverPath'] ?? '',
      downloadedAt: DateTime.parse(json['downloadedAt']),
    );
  }
}
