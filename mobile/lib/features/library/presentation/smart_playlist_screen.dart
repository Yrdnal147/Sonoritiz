import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../home/data/repositories/catalog_repository.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';

class SmartPlaylistScreen extends StatefulWidget {
  const SmartPlaylistScreen({Key? key}) : super(key: key);

  @override
  State<SmartPlaylistScreen> createState() => _SmartPlaylistScreenState();
}

class _SmartPlaylistScreenState extends State<SmartPlaylistScreen> {
  bool _isLoading = false;
  List<TrackModel> _generatedTracks = [];
  final TextEditingController _customMoodController = TextEditingController();

  final List<Map<String, dynamic>> _predefinedMoods = [
    {'title': 'Chill', 'icon': Icons.weekend_rounded, 'query': 'Chill relaxing vibes'},
    {'title': 'Sport', 'icon': Icons.fitness_center_rounded, 'query': 'Workout hype motivation'},
    {'title': 'Concentration', 'icon': Icons.menu_book_rounded, 'query': 'LoFi focus study'},
    {'title': 'Soirée', 'icon': Icons.celebration_rounded, 'query': 'Party dance hit'},
    {'title': 'Triste', 'icon': Icons.water_drop_rounded, 'query': 'Sad emotional'},
    {'title': 'Nostalgie', 'icon': Icons.history_rounded, 'query': '2000s throwback hits'},
  ];

  Future<void> _generatePlaylist(String query) async {
    setState(() {
      _isLoading = true;
      _generatedTracks = [];
    });

    try {
      final repo = CatalogRepository(apiClient: ApiClient(storageService: StorageService()));
      final tracks = await repo.generateSmartPlaylist(query);

      if (mounted) {
        setState(() {
          _generatedTracks = tracks;
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

  void _playAll() {
    if (_generatedTracks.isNotEmpty) {
      context.read<PlayerCubit>().playTrack(_generatedTracks.first, queue: _generatedTracks);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text("Générateur Magique", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Comment vous sentez-vous ?",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    "L'IA générera une playlist parfaite pour votre humeur.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _predefinedMoods.map((mood) {
                      return InkWell(
                        onTap: () => _generatePlaylist(mood['query']!),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(mood['icon'] as IconData, color: AppColors.primary, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                mood['title'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().scale(delay: 200.ms);
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _customMoodController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Ou tapez votre humeur...",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
                        onPressed: () {
                          if (_customMoodController.text.isNotEmpty) {
                            _generatePlaylist(_customMoodController.text);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (val) {
                      if (val.isNotEmpty) _generatePlaylist(val);
                    },
                  ).animate().fadeIn(delay: 300.ms),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_generatedTracks.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Playlist générée (${_generatedTracks.length})",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _playAll,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text("Tout lire"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = _generatedTracks[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        track.coverUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 50,
                          color: AppColors.surfaceLight,
                          child: const Icon(Icons.music_note, color: Colors.white),
                        ),
                      ),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                    onTap: () {
                      context.read<PlayerCubit>().playTrack(track, queue: _generatedTracks);
                    },
                  ).animate().fadeIn(delay: Duration(milliseconds: 50 * index));
                },
                childCount: _generatedTracks.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
          ],
        ],
      ),
    );
  }
}
