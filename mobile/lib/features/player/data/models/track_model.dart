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
    Uri? parsedArtUri;
    if (coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('file://')) {
        parsedArtUri = Uri.file(coverUrl.replaceFirst('file://', ''));
      } else if (coverUrl.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(coverUrl)) {
        parsedArtUri = Uri.file(coverUrl);
      } else {
        parsedArtUri = Uri.tryParse(coverUrl);
      }
    }
    return MediaItem(
      id: id,
      album: albumName.isNotEmpty ? albumName : 'Sonoritiz',
      title: title,
      artist: artistName,
      duration: Duration(seconds: durationSeconds),
      artUri: parsedArtUri,
      extras: {
        'audio_url': audioUrl,
        'license_ccurl': licenseCcUrl,
        'genre': genre,
      },
    );
  }

  /// Indique strictement si l'élément est un Podcast ou un Livre audio (et non un son musical).
  bool get isPodcastOrBook {
    final lowerId = id.trim().toLowerCase();
    if (lowerId.startsWith('deezer_podcast_') ||
        lowerId.startsWith('deezer_pod_') ||
        lowerId.startsWith('deezer_book_') ||
        lowerId.startsWith('itunes_pod_') ||
        lowerId.startsWith('itunes_book_')) {
      return true;
    }
    final lowerGenre = genre.trim().toLowerCase();
    if (lowerGenre.contains('podcast') ||
        lowerGenre.contains('livre') ||
        lowerGenre.contains('audiobook') ||
        lowerGenre == 'fun & vidéo') {
      return true;
    }
    return false;
  }

  TrackModel copyWith({
    String? id,
    String? title,
    String? artistName,
    String? albumName,
    String? coverUrl,
    int? durationSeconds,
    String? audioUrl,
    String? genre,
    String? licenseCcUrl,
  }) {
    return TrackModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      coverUrl: coverUrl ?? this.coverUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      audioUrl: audioUrl ?? this.audioUrl,
      genre: genre ?? this.genre,
      licenseCcUrl: licenseCcUrl ?? this.licenseCcUrl,
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
