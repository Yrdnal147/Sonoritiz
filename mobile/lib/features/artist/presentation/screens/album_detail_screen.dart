import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/share_utils.dart';
import '../../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../library/data/repositories/library_repository.dart';
import '../../../library/presentation/cubit/library_cubit.dart';
import '../../../library/presentation/cubit/library_state.dart';
import '../../../player/data/models/track_model.dart';
import '../../../search/presentation/cubit/search_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Map<String, dynamic> albumData;

  const AlbumDetailScreen({Key? key, required this.albumData}) : super(key: key);

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<TrackModel> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _title = '';
  String _cover = '';
  String _artistName = '';
  String _year = '';

  @override
  void initState() {
    super.initState();
    _initFromData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTracks();
    });
  }

  int? _extractId(Map<String, dynamic> data) {
    if (data['id'] != null) {
      return int.tryParse(data['id'].toString());
    }
    if (data['album'] is Map && (data['album'] as Map)['id'] != null) {
      return int.tryParse((data['album'] as Map)['id'].toString());
    }
    return null;
  }

  String _extractTitle(Map<String, dynamic> data) {
    if (data['title'] != null && data['title'].toString().trim().isNotEmpty) {
      return data['title'].toString().trim();
    }
    if (data['album'] is Map && (data['album'] as Map)['title'] != null) {
      return (data['album'] as Map)['title'].toString().trim();
    }
    return '';
  }

  String _extractCover(Map<String, dynamic> data) {
    if (data['cover_xl'] != null && data['cover_xl'].toString().trim().isNotEmpty) {
      return data['cover_xl'].toString().trim();
    }
    if (data['cover'] != null && data['cover'].toString().trim().isNotEmpty) {
      return data['cover'].toString().trim();
    }
    if (data['picture_xl'] != null && data['picture_xl'].toString().trim().isNotEmpty) {
      return data['picture_xl'].toString().trim();
    }
    if (data['picture'] != null && data['picture'].toString().trim().isNotEmpty) {
      return data['picture'].toString().trim();
    }
    if (data['album'] is Map) {
      final a = data['album'] as Map;
      if (a['cover_xl'] != null && a['cover_xl'].toString().trim().isNotEmpty) {
        return a['cover_xl'].toString().trim();
      }
      if (a['cover_medium'] != null && a['cover_medium'].toString().trim().isNotEmpty) {
        return a['cover_medium'].toString().trim();
      }
      if (a['cover'] != null && a['cover'].toString().trim().isNotEmpty) {
        return a['cover'].toString().trim();
      }
    }
    return '';
  }

  String _extractArtist(Map<String, dynamic> data) {
    if (data['artistName'] != null && data['artistName'].toString().trim().isNotEmpty) {
      return data['artistName'].toString().trim();
    }
    if (data['artist_name'] != null && data['artist_name'].toString().trim().isNotEmpty) {
      return data['artist_name'].toString().trim();
    }
    if (data['creator'] != null && data['creator'].toString().trim().isNotEmpty) {
      return data['creator'].toString().trim();
    }
    if (data['artist'] is Map && (data['artist'] as Map)['name'] != null) {
      return (data['artist'] as Map)['name'].toString().trim();
    }
    if (data['album'] is Map && (data['album'] as Map)['artist'] is Map && ((data['album'] as Map)['artist'] as Map)['name'] != null) {
      return (((data['album'] as Map)['artist'] as Map)['name']).toString().trim();
    }
    return '';
  }

  String _extractYear(Map<String, dynamic> data) {
    String date = '';
    if (data['release_date'] != null) date = data['release_date'].toString().trim();
    if (date.isEmpty && data['album'] is Map && (data['album'] as Map)['release_date'] != null) {
      date = (data['album'] as Map)['release_date'].toString().trim();
    }
    return date.length >= 4 ? date.substring(0, 4) : '';
  }

  void _initFromData() {
    _title = _extractTitle(widget.albumData);
    _cover = _extractCover(widget.albumData);
    _artistName = _extractArtist(widget.albumData);
    _year = _extractYear(widget.albumData);
  }

  Future<void> _fetchTracks() async {
    final repository = context.read<SearchCubit>().repository;
    try {
      final id = _extractId(widget.albumData);
      if (id == null || id == 0) {
        throw Exception("Identifiant introuvable.");
      }

      String title = _title;
      String cover = _cover;
      String artist = _artistName;
      String year = _year;

      final bool isPlaylist = widget.albumData['type'] == 'playlist' ||
          widget.albumData['is_playlist'] == true ||
          widget.albumData['record_type'] == 'playlist';

      // Si des métadonnées essentielles manquent, on les récupère via Deezer
      if (!isPlaylist && (title.isEmpty || cover.isEmpty || artist.isEmpty)) {
        final details = await repository.getAlbumDetailsDeezer(id);
        if (details != null) {
          if (title.isEmpty) title = details['title']?.toString() ?? 'Album';
          if (cover.isEmpty) {
            cover = details['cover_xl']?.toString() ??
                details['cover_big']?.toString() ??
                details['cover_medium']?.toString() ??
                details['cover']?.toString() ??
                '';
          }
          if (artist.isEmpty && details['artist'] is Map) {
            artist = details['artist']['name']?.toString() ?? 'Artiste Inconnu';
          }
          if (year.isEmpty && details['release_date'] != null) {
            final rel = details['release_date'].toString();
            if (rel.length >= 4) year = rel.substring(0, 4);
          }
        }
      }

      List<TrackModel> tracks = [];
      if (isPlaylist) {
        tracks = await repository.getPlaylistTracksDeezer(id, limit: 100);
      } else {
        tracks = await repository.getAlbumTracksDeezer(
          id,
          cover,
          artist.isNotEmpty ? artist : 'Artiste Inconnu',
          albumTitle: title.isNotEmpty ? title : 'Album',
        );
      }

      if (mounted) {
        setState(() {
          _title = title.isNotEmpty ? title : (isPlaylist ? 'Playlist' : 'Album');
          _cover = cover;
          _artistName = artist.isNotEmpty ? artist : 'Sonoritiz';
          _year = year;
          _tracks = tracks;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  bool get _isPlaylist =>
      widget.albumData['type'] == 'playlist' ||
      widget.albumData['is_playlist'] == true ||
      widget.albumData['record_type'] == 'playlist';

  String _formatTotalDuration() {
    if (_tracks.isEmpty) return '';
    int totalSeconds = 0;
    for (final t in _tracks) {
      totalSeconds += t.durationSeconds > 0 ? t.durationSeconds : 195;
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '$hours h ${minutes.toString().padLeft(2, '0')} min';
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = _title.isNotEmpty ? _title : (_isPlaylist ? 'Playlist' : 'Album');
    final displayArtist = _artistName.isNotEmpty ? _artistName : 'Sonoritiz';
    final playbackSource =
        _isPlaylist ? "la playlist $displayTitle" : "$displayArtist • $displayTitle";
    final totalDuration = _formatTotalDuration();

    final metaParts = <String>[
      if (!_isPlaylist && _year.isNotEmpty) _year,
      if (_tracks.isNotEmpty)
        "${_tracks.length} ${_tracks.length > 1 ? 'titres' : 'titre'}",
      if (totalDuration.isNotEmpty) totalDuration,
    ];

    final bool canOpenArtist = !_isPlaylist &&
        displayArtist.isNotEmpty &&
        displayArtist != 'Artiste Inconnu' &&
        displayArtist != 'Sonoritiz';

    final String heroCover = _cover.isNotEmpty
        ? _cover
        : (_tracks.isNotEmpty ? _tracks.first.coverUrl : '');
    final String? albumIdStr = _extractId(widget.albumData)?.toString();

    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, libState) {
        final libraryCubit = context.read<LibraryCubit>();
        final bool isAlbumLiked = !_isPlaylist &&
            libraryCubit.isAlbumFavorite(
              albumId: albumIdStr,
              title: displayTitle,
              artistName: displayArtist,
            );

        Future<void> onToggleAlbumLike() async {
          final isNowLiked = await libraryCubit.toggleFavoriteAlbum(
            albumId: albumIdStr,
            title: displayTitle,
            artistName: displayArtist,
            coverUrl: heroCover,
            year: _year,
            albumTracks: _tracks,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF181820),
              behavior: SnackBarBehavior.floating,
              content: Text(
                isNowLiked
                    ? (_tracks.isNotEmpty
                        ? "Album et ses ${_tracks.length} titres ajoutés aux favoris !"
                        : "Album ajouté aux albums favoris !")
                    : "Album retiré des albums favoris.",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        return SonoritizCollectionScaffold(
          title: displayTitle,
          badgeLabel: _isPlaylist ? 'SÉLECTION ÉDITORIALE' : 'ALBUM STUDIO',
          subtitle: displayArtist,
          onSubtitleTap: canOpenArtist
              ? () => context.push('/artist', extra: {'name': displayArtist})
              : null,
          metadata: metaParts.isEmpty ? null : metaParts.join(' • '),
          coverUrl: heroCover,
          playlistMosaic: _isPlaylist && heroCover.isEmpty && _tracks.isNotEmpty
              ? PlaylistModel(
                  id: _extractId(widget.albumData) ?? -1,
                  name: displayTitle,
                  tracks: _tracks,
                )
              : null,
          tracks: _tracks,
          playbackSource: playbackSource,
          isLoading: _isLoading,
          errorMessage: _errorMessage != null
              ? '${_isPlaylist ? "Impossible de charger la playlist" : "Impossible de charger l'album"}\n${_errorMessage!}'
              : null,
          onRetry: () {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
            _fetchTracks();
          },
          emptyMessage: 'Aucun morceau disponible actuellement.',
          showTrackCovers: _isPlaylist,
          trailingActionButton: _isPlaylist
              ? null
              : GestureDetector(
                  onTap: onToggleAlbumLike,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isAlbumLiked
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isAlbumLiked
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      isAlbumLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isAlbumLiked ? Colors.black : Colors.white,
                      size: 23,
                    ),
                  ),
                ),
          appBarActions: [
            if (!_isPlaylist)
              IconButton(
                tooltip: isAlbumLiked ? "Retirer des albums favoris" : "Liker l'album entier",
                icon: Icon(
                  isAlbumLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isAlbumLiked ? AppColors.primary : Colors.white,
                ),
                onPressed: onToggleAlbumLike,
              ),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: () {
                if (_tracks.isNotEmpty) {
                  ShareUtils.shareTrack(_tracks.first);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isPlaylist ? 'Playlist partagée !' : 'Album partagé !',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
