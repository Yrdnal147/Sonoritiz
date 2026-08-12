import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/artist_name_display.dart';
import '../../../player/presentation/cubit/player_cubit.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../../player/data/models/track_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

class ArtistPlaylistScreen extends StatefulWidget {
  final String artistName;

  const ArtistPlaylistScreen({Key? key, required this.artistName}) : super(key: key);

  @override
  State<ArtistPlaylistScreen> createState() => _ArtistPlaylistScreenState();
}

class _ArtistPlaylistScreenState extends State<ArtistPlaylistScreen> {
  late CatalogRepository _repository;
  bool _isLoading = true;
  List<TrackModel> _tracks = [];

  @override
  void initState() {
    super.initState();
    final storage = StorageService();
    _repository = CatalogRepository(apiClient: ApiClient(storageService: storage));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tracks = await _repository.getArtistTopTracks(widget.artistName, limit: 20);
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.artistName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [
                  Shadow(color: Colors.black, blurRadius: 10),
                ]),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.primary.withOpacity(0.3),
                    child: const Icon(Icons.person, size: 120, color: Colors.white30),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.background.withOpacity(0.8), AppColors.background],
                        stops: const [0.4, 0.8, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (!_isLoading && _tracks.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: AppColors.primary, size: 32),
                  onPressed: () => context.read<PlayerCubit>().playTrack(_tracks.first, queue: _tracks),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoading()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: track.coverUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(width: 56, height: 56, color: AppColors.surfaceLight),
                          ),
                        ),
                        title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: ArtistNameDisplay(
                          artistName: track.artistName,
                          style: const TextStyle(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.play_circle_fill, color: AppColors.primary),
                        onTap: () {
                          context.read<PlayerCubit>().playTrack(track, queue: _tracks);
                          context.push('/fullscreen');
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 10,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Shimmer.fromColors(
          baseColor: AppColors.surface,
          highlightColor: AppColors.surfaceLight,
          child: Row(
            children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 16, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 12, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
