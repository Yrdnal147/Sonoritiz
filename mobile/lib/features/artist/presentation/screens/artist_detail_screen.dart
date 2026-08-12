import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_artistName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 100)), // Appbar spacing
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
                      child: const Text("Top Sorties", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
                      child: const Text("Tous les Titres", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildArtistIdentityCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212), // Noir absolu
        border: Border.all(color: AppColors.primary, width: 3.0),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _imageUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: _imageUrl, width: 100, height: 100, fit: BoxFit.cover)
                    : Container(
                        width: 100, height: 100, color: AppColors.surfaceLight,
                        child: Center(child: Text(_artistName.isNotEmpty ? _artistName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 40))),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _artistName.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Nom : $_realName",
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _bio,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSorties() {
    return SizedBox(
      height: 180,
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
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: track.coverUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: track.coverUrl, width: 120, height: 120, fit: BoxFit.cover)
                        : (_imageUrl.isNotEmpty 
                            ? CachedNetworkImage(imageUrl: _imageUrl, width: 120, height: 120, fit: BoxFit.cover)
                            : Container(width: 120, height: 120, color: AppColors.surfaceLight)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
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
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: track.coverUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: track.coverUrl, width: 40, height: 40, fit: BoxFit.cover)
                      : (_imageUrl.isNotEmpty 
                          ? CachedNetworkImage(imageUrl: _imageUrl, width: 40, height: 40, fit: BoxFit.cover)
                          : Container(width: 40, height: 40, color: AppColors.surfaceLight)),
                ),
              ],
            ),
            title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: Text("${(track.durationSeconds ~/ 60)}:${(track.durationSeconds % 60).toString().padLeft(2, '0')}", style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onPressed: () => TrackContextMenu.show(context, track),
            ),
            onTap: () => context.read<PlayerCubit>().playTrack(track, queue: _allSons),
          );
        },
        childCount: _allSons.length,
      ),
    );
  }
}
