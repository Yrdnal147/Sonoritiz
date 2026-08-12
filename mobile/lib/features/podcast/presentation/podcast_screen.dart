import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../home/data/repositories/catalog_repository.dart';
import '../../../../core/widgets/artist_name_display.dart';
import '../../player/data/models/track_model.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({Key? key}) : super(key: key);

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  List<TrackModel> _podcasts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPodcasts();
  }

  Future<void> _fetchPodcasts({String query = ''}) async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<CatalogRepository>();
      final results = await repo.getPodcasts(query: query, limit: 50);
      if (mounted) {
        setState(() {
          _podcasts = results;
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text("Podcasts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => _searchQuery = value,
              onSubmitted: (value) => _fetchPodcasts(query: value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Rechercher un podcast...",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _podcasts.isEmpty
                    ? const Center(child: Text("Aucun podcast trouvé", style: TextStyle(color: Colors.white54)))
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _podcasts.length,
                        itemBuilder: (context, index) {
                          final track = _podcasts[index];
                          return GestureDetector(
                            onTap: () {
                              context.push('/podcast_player', extra: track);
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: track.coverUrl,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(color: AppColors.surfaceLight),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  track.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                ArtistNameDisplay(
                                  artistName: track.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
