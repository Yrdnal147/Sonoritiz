import 'package:audio_service/audio_service.dart';
import 'package:equatable/equatable.dart';

class TrackModel extends Equatable {
  final String id;
  final String title;
  final String artistName;
  final String albumName;
  final String coverUrl;
  final int durationSeconds;
  final String audioUrl;
  final String genre;
  final String licenseCcUrl;

  const TrackModel({
    required this.id,
    required this.title,
    required this.artistName,
    this.albumName = '',
    this.coverUrl = '',
    required this.durationSeconds,
    required this.audioUrl,
    this.genre = '',
    this.licenseCcUrl = 'https://creativecommons.org/licenses/by/4.0/',
  });

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    return TrackModel(
      id: (json['id'] ?? json['youtube_id'] ?? '').toString(),
      title: json['title'] ?? json['name'] ?? 'Titre inconnu',
      artistName: json['artist_name'] ?? 'Artiste inconnu',
      albumName: json['album_name'] ?? '',
      coverUrl: json['cover_url'] ?? json['album_image'] ?? '',
      durationSeconds: int.tryParse(json['duration_seconds']?.toString() ?? json['duration']?.toString() ?? '0') ?? 0,
      audioUrl: json['audio_url'] ?? json['audio'] ?? '',
      genre: json['genre'] ?? '',
      licenseCcUrl: json['license_ccurl'] ?? 'https://creativecommons.org/licenses/by/4.0/',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist_name': artistName,
      'album_name': albumName,
      'cover_url': coverUrl,
      'duration_seconds': durationSeconds,
      'audio_url': audioUrl,
      'genre': genre,
      'license_ccurl': licenseCcUrl,
    };
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      album: albumName.isNotEmpty ? albumName : 'Sonoritiz',
      title: title,
      artist: artistName,
      duration: Duration(seconds: durationSeconds),
      artUri: coverUrl.isNotEmpty ? Uri.parse(coverUrl) : null,
      extras: {
        'audio_url': audioUrl,
        'license_ccurl': licenseCcUrl,
        'genre': genre,
      },
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        artistName,
        albumName,
        coverUrl,
        durationSeconds,
        audioUrl,
        genre,
        licenseCcUrl,
      ];
}
