import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/palette_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../player/presentation/cubit/player_cubit.dart';
import '../../../player/presentation/widgets/player_components/immersive_player_widgets.dart';
import '../../../player/data/models/track_model.dart';
import '../../../search/presentation/cubit/search_cubit.dart';
import '../../../../core/widgets/sonoritiz_track_tile.dart';
import '../widgets/artist_personalized_wordmark.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Map<String, String> artistInfo;

  const ArtistDetailScreen({Key? key, required this.artistInfo}) : super(key: key);

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  late String _artistName;

  Map<String, dynamic>? _artistDetails;
  List<TrackModel> _topTracks = [];
  List<Map<String, dynamic>> _albums = [];
  bool _isLoading = true;
  bool _isFollowed = false;
  bool _isBioExpanded = false;
  String? _errorMessage;
  ImmersivePalette _palette = ImmersivePalette.fallback;
  String _lastPaletteUrl = '';

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

      List<TrackModel> top = [];
      List<Map<String, dynamic>> albums = [];

      if (artistId != 0) {
        final results = await Future.wait([
          repository.getArtistTopTracksDeezer(artistId, limit: 10),
          repository.getArtistAlbumsDeezer(artistId),
        ]);
        top = results[0] as List<TrackModel>;
        albums = results[1] as List<Map<String, dynamic>>;
      }

      if (top.isEmpty) {
        final ytTracks = await repository.searchTracks(query: '$_artistName official audio');
        top = ytTracks.take(10).toList();
      }

      if (mounted) {
        final realName = (details['name'] ?? _artistName).toString();
        final resolvedImage =
            (details['picture_xl'] ?? widget.artistInfo['imageUrl'] ?? '').toString();
        setState(() {
          _artistDetails = details;
          _topTracks = top;
          _albums = albums;
          _isFollowed = StorageService().isArtistFollowed(realName) ||
              StorageService().isArtistFollowed(_artistName);
          _isLoading = false;
        });
        if (resolvedImage.isNotEmpty) {
          _extractArtistPalette(resolvedImage);
        }
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
    final Color playIconColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.light
            ? Colors.black
            : Colors.white;

    return Scaffold(
        backgroundColor: bgColor,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Grand Header immersif avec photo de l'artiste, nom personnalisé et fondu chromatique
                SliverAppBar(
                  backgroundColor: bgColor.withValues(alpha: 0.90),
                  expandedHeight: 380,
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
                            padding: const EdgeInsets.fromLTRB(24, 44, 24, 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ArtistPersonalizedWordmark(
                                  artistName: name,
                                  accentColor: accentColor,
                                ),
                                if (nbFan > 0 || nbAlbum > 0) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    [
                                      if (nbFan > 0) "${_formatNumber(nbFan)} fans",
                                      if (nbAlbum > 0) "$nbAlbum projet${nbAlbum > 1 ? 's' : ''}",
                                    ].join('  •  '),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.72),
                                      fontSize: 13,
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

                // Trio d'actions centré inspiré d'Apple Music : Aléatoire (gauche) • Lecture teintée (centre) • Suivre/Favori (droite)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_topTracks.isNotEmpty) ...[
                          _buildFrostedCircleAction(
                            icon: Icons.shuffle_rounded,
                            tooltip: "Lecture aléatoire",
                            onTap: () {
                              final shuffled = List<TrackModel>.from(_topTracks)..shuffle();
                              context.read<PlayerCubit>().playTrack(
                                shuffled.first,
                                queue: shuffled,
                                source: sourceLabel,
                              );
                            },
                          ),
                          const SizedBox(width: 22),
                          GestureDetector(
                            onTap: () {
                              context.read<PlayerCubit>().playTrack(
                                _topTracks.first,
                                queue: _topTracks,
                                source: sourceLabel,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.45),
                                    blurRadius: 22,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: playIconColor,
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(width: 22),
                        ],
                        _buildFrostedCircleAction(
                          icon: _isFollowed ? Icons.star_rounded : Icons.star_outline_rounded,
                          tooltip: _isFollowed ? "Suivi" : "Suivre",
                          isActive: _isFollowed,
                          activeColor: accentColor,
                          activeIconColor: playIconColor,
                          onTap: () => _toggleFollow(name),
                        ),
                      ],
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
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                                  color: Colors.white.withOpacity(0.78),
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
          ],
        ),
    );
  }

  Widget _buildFrostedCircleAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
    Color activeIconColor = Colors.black,
  }) {
    final Color fillColor = isActive && activeColor != null
        ? activeColor
        : Colors.white.withValues(alpha: 0.12);
    final Color borderColor = isActive && activeColor != null
        ? activeColor
        : Colors.white.withValues(alpha: 0.24);
    final Color iconColor =
        isActive && activeColor != null ? activeIconColor : Colors.white;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: fillColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.1),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
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
                          color: Colors.black.withOpacity(0.35),
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
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
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
