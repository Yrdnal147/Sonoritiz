import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/widgets/playlist_cover_mosaic.dart';
import '../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../../core/widgets/sonoritiz_track_tile.dart';
import '../../home/data/repositories/catalog_repository.dart';
import '../../library/data/repositories/library_repository.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';

class SmartPlaylistScreen extends StatefulWidget {
  const SmartPlaylistScreen({super.key});

  @override
  State<SmartPlaylistScreen> createState() => _SmartPlaylistScreenState();
}

class _SmartPlaylistScreenState extends State<SmartPlaylistScreen> {
  bool _isLoading = false;
  List<TrackModel> _generatedTracks = [];
  String? _activeLabel;
  final TextEditingController _customMoodController = TextEditingController();

  final List<Map<String, dynamic>> _predefinedMoods = [
    {'title': 'Chill', 'icon': Icons.weekend_rounded, 'query': 'Chill relaxing vibes'},
    {'title': 'Sport', 'icon': Icons.fitness_center_rounded, 'query': 'Workout hype motivation'},
    {'title': 'Concentration', 'icon': Icons.menu_book_rounded, 'query': 'LoFi focus study'},
    {'title': 'Soirée', 'icon': Icons.celebration_rounded, 'query': 'Party dance hit'},
    {'title': 'Triste', 'icon': Icons.water_drop_rounded, 'query': 'Sad emotional'},
    {'title': 'Nostalgie', 'icon': Icons.history_rounded, 'query': '2000s throwback hits'},
  ];

  @override
  void dispose() {
    _customMoodController.dispose();
    super.dispose();
  }

  Future<void> _generatePlaylist(String query, {String? label}) async {
    setState(() {
      _isLoading = true;
      _generatedTracks = [];
      _activeLabel = label ?? query;
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _playAll({bool shuffle = false}) {
    if (_generatedTracks.isEmpty) return;
    final list = shuffle ? (List<TrackModel>.from(_generatedTracks)..shuffle()) : _generatedTracks;
    final sourceLabel = _activeLabel != null ? "Mix $_activeLabel" : "Mix Thématique";
    context.read<PlayerCubit>().playTrack(list.first, queue: list, source: sourceLabel);
  }

  @override
  Widget build(BuildContext context) {
    final sourceLabel = _activeLabel != null ? "Mix $_activeLabel" : "Mix Thématique";
    final heroCover = _generatedTracks.isNotEmpty ? _generatedTracks.first.coverUrl : '';
    final mosaicPlaylist = _generatedTracks.length >= 3
        ? PlaylistModel(
            id: -1,
            name: sourceLabel,
            coverUrl: heroCover,
            tracks: _generatedTracks.take(4).toList(),
            tracksCount: _generatedTracks.length,
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const SonoritizPageTitle(
          title: 'Mix Thématique',
          fontSize: 22,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SonoritizCoverAtmosphere(
        coverUrl: heroCover,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + kToolbarHeight + 10,
                  20,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SonoritizPageTitle(
                      title: "Quelle énergie aujourd'hui ?",
                      fontSize: 28,
                      maxLines: 2,
                    ).animate().fadeIn().slideY(begin: 0.15, end: 0),
                    const SizedBox(height: 12),
                    Text(
                      "Compose une sélection sur mesure à partir d'une ambiance ou d'un mot-clé.",
                      style: TextStyle(
                        fontSize: 15.5,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _predefinedMoods.map((mood) {
                        final title = mood['title'] as String;
                        final isSelected = _activeLabel == title;
                        return GestureDetector(
                          onTap: () => _generatePlaylist(mood['query'] as String, label: title),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.22)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  mood['icon'] as IconData,
                                  color: isSelected ? AppColors.primary : Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _customMoodController,
                      style: const TextStyle(color: Colors.white, fontSize: 15.5),
                      decoration: InputDecoration(
                        hintText: "Ou tape un style, une humeur, un moment...",
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.queue_music_rounded, color: AppColors.primary),
                          onPressed: () {
                            final txt = _customMoodController.text.trim();
                            if (txt.isNotEmpty) {
                              _generatePlaylist(txt, label: txt);
                            }
                          },
                        ),
                      ),
                      onSubmitted: (val) {
                        final txt = val.trim();
                        if (txt.isNotEmpty) _generatePlaylist(txt, label: txt);
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_generatedTracks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                  child: Column(
                    children: [
                      if (mosaicPlaylist != null) ...[
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.52),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: PlaylistCoverMosaic(
                            playlist: mosaicPlaylist,
                            size: 168,
                            height: 176,
                            borderRadius: 20,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      SonoritizPageTitle(
                        title: _activeLabel ?? 'Sélection',
                        fontSize: 25,
                        maxLines: 2,
                        centered: true,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${_generatedTracks.length} ${_generatedTracks.length > 1 ? 'titres' : 'titre'}",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => _playAll(),
                                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                                label: const Text(
                                  'Lire',
                                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => _playAll(shuffle: true),
                                icon: const Icon(Icons.shuffle_rounded, size: 21),
                                label: const Text(
                                  'Aléatoire',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                                  foregroundColor: Colors.white,
                                  shape: StadiumBorder(
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = _generatedTracks[index];
                    return SonoritizTrackTile(
                      track: track,
                      queue: _generatedTracks,
                      index: index,
                      showCover: true,
                      playbackSource: sourceLabel,
                    );
                  },
                  childCount: _generatedTracks.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ],
        ),
      ),
    );
  }
}
