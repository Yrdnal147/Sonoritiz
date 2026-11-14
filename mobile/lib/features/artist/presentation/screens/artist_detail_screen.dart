import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/sonoritiz_page_title.dart';
import '../../../player/presentation/cubit/player_cubit.dart';
import '../../../player/data/models/track_model.dart';
import '../../../search/presentation/cubit/search_cubit.dart';
import '../../../../core/widgets/sonoritiz_track_tile.dart';

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

  @override
  void initState() {
    super.initState();
    _artistName = widget.artistInfo['name'] ?? 'Artiste Inconnu';
    _isFollowed = StorageService().isArtistFollowed(_artistName);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
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
        setState(() {
          _artistDetails = details;
          _topTracks = top;
          _albums = albums;
          _isFollowed = StorageService().isArtistFollowed(realName) ||
              StorageService().isArtistFollowed(_artistName);
          _isLoading = false;
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

    final imageUrl = (_artistDetails?['picture_xl'] ?? '').toString();
    final int nbFan = (_artistDetails?['nb_fan'] ?? 0) as int;
    final int nbAlbum = (_artistDetails?['nb_album'] ?? _albums.length) as int;
    final String bio = (_artistDetails?['bio'] ?? '').toString();
    final String name = (_artistDetails?['name'] ?? _artistName).toString();
    final String sourceLabel = "le profil de $name";

    return Scaffold(
        backgroundColor: AppColors.background,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Grand Header immersif avec photo de l'artiste et flou artistique
                SliverAppBar(
                  backgroundColor: AppColors.background.withOpacity(0.85),
                  expandedHeight: 330,
                  pinned: true,
                  elevation: 0,
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.45),
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
                        backgroundColor: Colors.black.withOpacity(0.45),
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
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.surfaceLight,
                            ),
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
                                Colors.black.withValues(alpha: 0.25),
                                Colors.black.withValues(alpha: 0.35),
                                AppColors.background.withValues(alpha: 0.92),
                                AppColors.background,
                              ],
                              stops: const [0.0, 0.45, 0.85, 1.0],
                            ),
                          ),
                        ),
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SonoritizPageTitle(
                                  title: name,
                                  fontSize: 34,
                                  maxLines: 2,
                                ),
                                if (nbFan > 0 || nbAlbum > 0) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    [
                                      if (nbFan > 0) "${_formatNumber(nbFan)} fans",
                                      if (nbAlbum > 0) "$nbAlbum projet${nbAlbum > 1 ? 's' : ''}",
                                    ].join('  •  '),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.68),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
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

                // Barre d'actions : Bouton Suivre + Lecture + Aléatoire
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        // Bouton Suivre / Suivi
                        GestureDetector(
                          onTap: () => _toggleFollow(name),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                            decoration: BoxDecoration(
                              color: _isFollowed ? AppColors.primary : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: _isFollowed ? AppColors.primary : Colors.white.withOpacity(0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isFollowed ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
                                  color: _isFollowed ? Colors.black : Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isFollowed ? "Suivi" : "Suivre",
                                  style: TextStyle(
                                    color: _isFollowed ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Bouton Aléatoire
                        if (_topTracks.isNotEmpty) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 22),
                              tooltip: "Lecture aléatoire",
                              onPressed: () {
                                final shuffled = List<TrackModel>.from(_topTracks)..shuffle();
                                context.read<PlayerCubit>().playTrack(
                                  shuffled.first,
                                  queue: shuffled,
                                  source: sourceLabel,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Bouton Lire (Blanc comme dans le lecteur)
                          GestureDetector(
                            onTap: () {
                              context.read<PlayerCubit>().playTrack(
                                _topTracks.first,
                                queue: _topTracks,
                                source: sourceLabel,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                                  SizedBox(width: 6),
                                  Text(
                                    "Lire",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                          ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
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
