import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/palette_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../player/presentation/cubit/player_cubit.dart';
import '../../../player/presentation/cubit/player_state.dart';
import '../../../player/presentation/widgets/player_components/immersive_player_widgets.dart';
import '../../../player/data/models/track_model.dart';
import '../../../player/data/services/lyrics_service.dart';
import '../../../search/presentation/cubit/search_cubit.dart';
import '../../../search/presentation/widgets/sonoritiz_shorts_preview_row.dart';
import '../../../../core/widgets/sonoritiz_track_tile.dart';
import '../widgets/artist_personalized_wordmark.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Map<String, String> artistInfo;

  const ArtistDetailScreen({super.key, required this.artistInfo});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  late String _artistName;

  Map<String, dynamic>? _artistDetails;
  List<TrackModel> _topTracks = [];
  List<TrackModel> _artistVideoShorts = [];
  List<TrackModel> _artistAudioShorts = [];
  List<TrackModel> _artistSyncedLyricsShorts = [];
  bool _isLoadingSyncedLyrics = true;
  List<Map<String, dynamic>> _albums = [];
  bool _isLoading = true;
  bool _isFollowed = false;
  bool _isBioExpanded = false;
  String? _errorMessage;
  ImmersivePalette _palette = ImmersivePalette.fallback;
  String _lastPaletteUrl = '';
  final LyricsService _lyricsService = LyricsService();

  @override
  void initState() {
    super.initState();
    _artistName = widget.artistInfo['name'] ?? 'Artiste Inconnu';
    _isFollowed = StorageService().isArtistFollowed(_artistName);

    final initialImage = (widget.artistInfo['imageUrl'] ?? '').trim();
    if (initialImage.isNotEmpty) {
      final cached = PaletteService.getCached(initialImage);
      if (cached != null) {
        _palette = cached;
        _lastPaletteUrl = initialImage;
      } else {
        _extractArtistPalette(initialImage);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _extractArtistPalette(String url) async {
    final clean = url.trim();
    if (clean.isEmpty || clean == _lastPaletteUrl) return;
    _lastPaletteUrl = clean;
    final palette = await PaletteService.getPalette(clean);
    if (mounted) {
      setState(() {
        _palette = palette;
      });
    }
  }

  Future<void> _fetchData() async {
    final repository = context.read<SearchCubit>().repository;
    try {
      int artistId = int.tryParse((widget.artistInfo['id'] ?? '').toString()) ?? 0;
      Map<String, dynamic> details = {};

      // 1. Si un ID précis est fourni, charger directement par ID pour garantir l'exactitude absolue
      if (artistId > 0) {
        details = await repository.getArtistDetailsDeezerById(artistId);
      }

      // 2. Fallback par nom si l'ID n'a rien renvoyé ou n'était pas fourni
      if (details.isEmpty || (details['id'] ?? 0) == 0) {
        details = await repository.getArtistDetailsDeezer(_artistName);
        if (details.containsKey('id') && details['id'] is int) {
          artistId = details['id'] as int;
        }
      }

      // Enregistrer dans le registre des vrais artistes consultés
      if (details.isNotEmpty && (details['id'] ?? 0) != 0) {
        StorageService().recordSearchedArtist({
          'id': details['id']?.toString() ?? artistId.toString(),
          'name': details['name'] ?? _artistName,
          'image': details['picture_xl'] ?? widget.artistInfo['imageUrl'] ?? '',
        });
      }

      List<TrackModel> fetchedPool = [];
      List<Map<String, dynamic>> albums = [];

      if (artistId != 0) {
        final results = await Future.wait([
          repository.getArtistTopTracksDeezer(artistId, limit: 30),
          repository.getArtistAlbumsDeezer(artistId),
        ]);
        fetchedPool = results[0] as List<TrackModel>;
        albums = results[1] as List<Map<String, dynamic>>;
      }

      final String realName = (details['name'] ?? _artistName).toString();

      // Compléter jusqu'à 25 sons de l'artiste si le top Deezer en renvoie moins
      if (fetchedPool.length < 25) {
        try {
          final ytTracks = await repository.searchTracks(
            query: '$realName official video',
          );
          final existingTitles = fetchedPool
              .map((t) => t.title.toLowerCase().trim())
              .toSet();
          for (final yt in ytTracks) {
            final normTitle = yt.title.toLowerCase().trim();
            if (!existingTitles.contains(normTitle)) {
              existingTitles.add(normTitle);
              fetchedPool.add(yt);
              if (fetchedPool.length >= 28) break;
            }
          }
        } catch (_) {}
      }

      final List<TrackModel> top = fetchedPool.take(10).toList();
      final List<TrackModel> shortsPool = fetchedPool.take(25).toList();

      if (mounted) {
        final resolvedImage =
            (details['picture_xl'] ?? widget.artistInfo['imageUrl'] ?? '').toString();
        setState(() {
          _artistDetails = details;
          _topTracks = top;
          _artistVideoShorts = List<TrackModel>.from(shortsPool);
          _artistAudioShorts = List<TrackModel>.from(shortsPool);
          _albums = albums;
          _isFollowed = StorageService().isArtistFollowed(realName) ||
              StorageService().isArtistFollowed(_artistName);
          _isLoading = false;
        });
        if (resolvedImage.isNotEmpty) {
          _extractArtistPalette(resolvedImage);
        }
        _filterSyncedLyricsShorts(shortsPool);
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

  /// Filtre uniquement les sons de l'artiste qui possèdent des paroles synchronisées (LRC horodaté)
  /// pour alimenter la carte Karaoké / Lyrics Shorts de l'artiste (jusqu'à 25 titres).
  Future<void> _filterSyncedLyricsShorts(List<TrackModel> candidates) async {
    if (candidates.isEmpty) {
      if (mounted) {
        setState(() => _isLoadingSyncedLyrics = false);
      }
      return;
    }

    final List<TrackModel> syncedOnly = [];
    const int batchSize = 5;

    for (int i = 0; i < candidates.length && syncedOnly.length < 25; i += batchSize) {
      if (!mounted) return;
      final end = (i + batchSize < candidates.length) ? i + batchSize : candidates.length;
      final batch = candidates.sublist(i, end);

      final results = await Future.wait(
        batch.map((track) async {
          try {
            final lyrics = await _lyricsService.getLyrics(
              track.id,
              track.artistName,
              track.title,
              track.durationSeconds,
            );
            if (lyrics != null &&
                lyrics.hasSynced &&
                lyrics.parsedSyncedLyrics != null &&
                lyrics.parsedSyncedLyrics!.isNotEmpty) {
              return track;
            }
          } catch (_) {}
          return null;
        }),
      );

      for (final matched in results) {
        if (matched != null && syncedOnly.length < 25) {
          syncedOnly.add(matched);
        }
      }

      if (mounted && syncedOnly.isNotEmpty) {
        setState(() {
          _artistSyncedLyricsShorts = List<TrackModel>.from(syncedOnly);
        });
      }
    }

    if (mounted) {
      setState(() {
        _artistSyncedLyricsShorts = List<TrackModel>.from(syncedOnly);
        _isLoadingSyncedLyrics = false;
      });
    }
  }

  Future<void> _toggleFollow(String name) async {
    final nowFollowed = await StorageService().toggleFollowArtist(name);
    if (mounted) {
      setState(() {
        _isFollowed = nowFollowed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nowFollowed ? "Vous suivez maintenant $name" : "Vous ne suivez plus $name",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatNumber(int number) {
    return NumberFormat.decimalPattern('fr').format(number);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text("Erreur: $_errorMessage", style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    final imageUrl =
        (_artistDetails?['picture_xl'] ?? widget.artistInfo['imageUrl'] ?? '').toString();
    final int nbFan = (_artistDetails?['nb_fan'] ?? 0) as int;
    final int nbAlbum = (_artistDetails?['nb_album'] ?? _albums.length) as int;
    final String bio = (_artistDetails?['bio'] ?? '').toString();
    final String name = (_artistDetails?['name'] ?? _artistName).toString();
    final String sourceLabel = "le profil de $name";

    final Color bgColor = _palette.deepColor;
    final Color accentColor = _palette.accentColor;
    // Règle chromatique unifiée (soulignement centré du nom & background des 3 boutons) :
    // Orange primaire par défaut, ou Blanc / Noir selon la pochette si la photo est proche de l'Orange.
    final Color adaptiveColor =
        ArtistPersonalizedWordmark.resolveAdaptivePrimaryColor(_palette);
    final Color adaptiveFgColor =
        ArtistPersonalizedWordmark.resolveForegroundOn(adaptiveColor);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      body: SonoritizCoverAtmosphere(
        coverUrl: imageUrl,
        accentFallback: accentColor,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Grand Header immersif avec photo de l'artiste, nom personnalisé souligné au milieu et fondu atmosphérique
            SliverAppBar(
              backgroundColor: bgColor.withValues(alpha: 0.90),
              expandedHeight: 370,
              pinned: true,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.45),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    child: IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profil artiste partagé !')),
                        );
                      },
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      SonoritizArtwork(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 0,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      )
                    else
                      Container(
                        color: AppColors.surfaceLight,
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 96,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.22),
                            Colors.black.withValues(alpha: 0.18),
                            bgColor.withValues(alpha: 0.86),
                            bgColor,
                          ],
                          stops: const [0.0, 0.46, 0.84, 1.0],
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 44, 24, 14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ArtistPersonalizedWordmark(
                              artistName: name,
                              accentColor: accentColor,
                              underlineColor: adaptiveColor,
                            ),
                            if (nbFan > 0 || nbAlbum > 0) ...[
                              const SizedBox(height: 10),
                              Text(
                                [
                                  if (nbFan > 0) "${_formatNumber(nbFan)} fans",
                                  if (nbAlbum > 0) "$nbAlbum projet${nbAlbum > 1 ? 's' : ''}",
                                ].join('  •  '),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sous la photo : Cadre Glassmorphism transparent contenant les boutons
            // - Lire et Aléatoire : uniquement en logo (icône seule)
            // - Suivre : garde son identité (icône + texte)
            // - Les 3 boutons appliquent le principe chromatique adaptatif sur leur background
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: BlocBuilder<PlayerCubit, PlayerState>(
                  builder: (context, playerState) {
                    final bool isThisArtistPlaying =
                        playerState.isPlaying &&
                            playerState.currentTrack != null &&
                            _topTracks.any(
                              (t) => t.id == playerState.currentTrack!.id,
                            );

                    return Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_topTracks.isNotEmpty) ...[
                                  // 1. Bouton Lire / Pause (uniquement en logo)
                                  Tooltip(
                                    message:
                                        isThisArtistPlaying ? "Pause" : "Lire",
                                    child: GestureDetector(
                                      onTap: () {
                                        final cubit =
                                            context.read<PlayerCubit>();
                                        if (isThisArtistPlaying) {
                                          cubit.togglePlayPause();
                                        } else {
                                          cubit.playTrack(
                                            _topTracks.first,
                                            queue: _topTracks,
                                            source: sourceLabel,
                                          );
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: adaptiveColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: adaptiveColor == Colors.black
                                                ? Colors.white.withValues(
                                                    alpha: 0.28,
                                                  )
                                                : adaptiveColor,
                                            width: 1.1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: adaptiveColor.withValues(
                                                alpha: 0.35,
                                              ),
                                              blurRadius: 14,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          isThisArtistPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: adaptiveFgColor,
                                          size: 27,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 2. Bouton Aléatoire (uniquement en logo)
                                  Tooltip(
                                    message: "Lecture aléatoire",
                                    child: GestureDetector(
                                      onTap: () {
                                        final shuffled =
                                            List<TrackModel>.from(_topTracks)
                                              ..shuffle();
                                        context.read<PlayerCubit>().playTrack(
                                              shuffled.first,
                                              queue: shuffled,
                                              source: sourceLabel,
                                            );
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: adaptiveColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: adaptiveColor == Colors.black
                                                ? Colors.white.withValues(
                                                    alpha: 0.28,
                                                  )
                                                : adaptiveColor,
                                            width: 1.1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.shuffle_rounded,
                                          color: adaptiveFgColor,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                ],
                                // 3. Bouton Suivre (garde son identité icône + texte avec le même principe de background)
                                _buildFollowTrailingButton(
                                  name: name,
                                  adaptiveBgColor: adaptiveColor,
                                  adaptiveFgColor: adaptiveFgColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Section Titres Populaires
            if (_topTracks.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    "Titres populaires",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
              _buildTopTracksList(sourceLabel),
            ],

            // Section Discographie / Albums
            if (_albums.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text(
                    "Discographie",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildAlbumsList(name)),
            ],

            // Section "<Nom de l'artiste> Shorts" (Clips Vidéo 25 • Audio 25 • Karaoké Lyrics synchrones 25 • 45s sur les moments forts)
            if (_artistVideoShorts.isNotEmpty ||
                _artistAudioShorts.isNotEmpty ||
                _artistSyncedLyricsShorts.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$name Shorts",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Les Sonoritiz Shorts de $name • 45s sur les moments forts",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SonoritizShortsPreviewRow(
                    compact: true,
                    customVideoTracks: _artistVideoShorts,
                    customAudioTracks: _artistAudioShorts,
                    customLyricsTracks: _artistSyncedLyricsShorts,
                    customIsLoading: _isLoadingSyncedLyrics,
                    artistName: name,
                    clipDurationSeconds: 45,
                    focusHighlight: true,
                  ),
                ),
              ),
            ],

                // Section Biographie ("À propos")
                if (bio.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: GestureDetector(
                        onTap: () => setState(() => _isBioExpanded = !_isBioExpanded),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "À propos de $name",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Icon(
                                    _isBioExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                bio,
                                maxLines: _isBioExpanded ? 30 : 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 14,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
    );
  }

  Widget _buildFollowTrailingButton({
    required String name,
    required Color adaptiveBgColor,
    required Color adaptiveFgColor,
  }) {
    final Color borderColor = adaptiveBgColor == Colors.black
        ? Colors.white.withValues(alpha: 0.30)
        : adaptiveBgColor;

    return GestureDetector(
      onTap: () => _toggleFollow(name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: adaptiveBgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isFollowed
                  ? Icons.check_rounded
                  : Icons.person_add_alt_1_rounded,
              color: adaptiveFgColor,
              size: 19,
            ),
            const SizedBox(width: 8),
            Text(
              _isFollowed ? "Suivi" : "Suivre",
              style: TextStyle(
                color: adaptiveFgColor,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTracksList(String sourceLabel) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = _topTracks[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: SonoritizTrackTile(
              track: track,
              queue: _topTracks,
              index: index,
              playbackSource: sourceLabel,
            ),
          );
        },
        childCount: _topTracks.length,
      ),
    );
  }

  Widget _buildAlbumsList(String artistName) {
    return SizedBox(
      height: 224,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _albums.length,
        itemBuilder: (context, index) {
          final album = _albums[index];
          final title = album['title'] ?? 'Album inconnu';
          final cover = album['cover_xl'] ?? '';
          final releaseDate = (album['release_date'] ?? '').toString();
          final year = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';

          return GestureDetector(
            onTap: () {
              context.push('/album', extra: {'album': album, 'artistName': artistName});
            },
            child: Container(
              width: 148,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: cover.isNotEmpty
                          ? SonoritizArtwork(
                              imageUrl: cover,
                              width: 148,
                              height: 148,
                              borderRadius: 14,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.album, size: 50, color: Colors.white24),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    year.isNotEmpty ? "Album • $year" : "Album",
                    maxLines: 1,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
