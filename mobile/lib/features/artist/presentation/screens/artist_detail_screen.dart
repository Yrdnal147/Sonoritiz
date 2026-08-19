import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/artist_ambient_background.dart';
import '../../../player/presentation/cubit/player_cubit.dart';
import '../../../player/data/models/track_model.dart';
import '../../../search/presentation/cubit/search_cubit.dart';
import '../../../../core/widgets/track_context_menu.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Map<String, String> artistInfo;

  const ArtistDetailScreen({Key? key, required this.artistInfo}) : super(key: key);

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  late String _artistName;
  late String _imageUrl;
  late String _realName;
  late String _bio;
  
  final List<TrackModel> _topSorties = [];
  final List<TrackModel> _allSons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _artistName = widget.artistInfo['name'] ?? 'Artiste Inconnu';
    _imageUrl = widget.artistInfo['imageUrl'] ?? '';
    
    // We don't have real name and bio in our mock database or Youtube API directly,
    // so we set sensible defaults.
    _realName = _artistName;
    _bio = "Découvrez les meilleurs titres et les nouveautés de $_artistName sur Sonoritiz. Retrouvez ses plus grands succès et ses dernières sorties.";
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTracks();
    });
  }
  
  Future<void> _fetchTracks() async {
    final repository = context.read<SearchCubit>().repository;
    try {
      // Fetch dynamic bio from Wikipedia
      final dynamicBio = await repository.getArtistBio(_artistName);
      
      final top = await repository.getArtistTopTracks(_artistName, limit: 14);
      final all = await repository.searchTracks(query: _artistName, limit: 50);
      
      if (mounted) {
        setState(() {
          _bio = dynamicBio;
          _topSorties.addAll(top);
          _allSons.addAll(all);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArtistAmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    pinned: true,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    flexibleSpace: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: FlexibleSpaceBar(
                          title: Text(_artistName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.white, letterSpacing: -0.5)),
                          centerTitle: true,
                          background: Container(
                            color: AppColors.background.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildArtistIdentityCard(),
                      ),
                    ),
                  ),
                  if (_topSorties.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16),
                        child: const Text("Top Sorties", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildTopSorties(),
                    ),
                  ],
                  if (_allSons.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 32, bottom: 16, left: 16),
                        child: const Text("Tous les Titres", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      ),
                    ),
                    _buildAllSonsList(),
                  ],
                  if (_topSorties.isEmpty && _allSons.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text("Aucun titre trouvé pour cet artiste.", style: const TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)), // Space for mini player
                ],
              ),
      ),
    );
  }

  Widget _buildArtistIdentityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.0),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
          )
        ]
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ]
                ),
                child: ClipOval(
                  child: _imageUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: _imageUrl, width: 100, height: 100, fit: BoxFit.cover)
                      : Container(
                          width: 100, height: 100, color: AppColors.surfaceLight,
                          child: Center(child: Text(_artistName.isNotEmpty ? _artistName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 40))),
                        ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _artistName,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Artiste",
                      style: TextStyle(color: AppColors.primary.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _bio,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSorties() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _topSorties.length,
        itemBuilder: (context, index) {
          final track = _topSorties[index];
          return GestureDetector(
            onTap: () => context.read<PlayerCubit>().playTrack(track, queue: _topSorties),
            onLongPress: () => TrackContextMenu.show(context, track),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: track.coverUrl.isNotEmpty
                          ? CachedNetworkImage(imageUrl: track.coverUrl, fit: BoxFit.cover)
                          : (_imageUrl.isNotEmpty 
                              ? CachedNetworkImage(imageUrl: _imageUrl, fit: BoxFit.cover)
                              : Container(color: AppColors.surfaceLight)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAllSonsList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = _allSons[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: track.coverUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: track.coverUrl, width: 48, height: 48, fit: BoxFit.cover)
                        : Container(width: 48, height: 48, color: AppColors.surfaceLight),
                  ),
                ],
              ),
              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(track.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle_fill, color: AppColors.primary, size: 32),
                onPressed: () => context.read<PlayerCubit>().playTrack(track, queue: _allSons),
              ),
              onTap: () => context.read<PlayerCubit>().playTrack(track, queue: _allSons),
              onLongPress: () => TrackContextMenu.show(context, track),
            ),
          );
        },
        childCount: _allSons.length,
      ),
    );
  }
}
