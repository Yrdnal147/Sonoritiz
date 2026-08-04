import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';

class ArtistDetailScreen extends StatelessWidget {
  final String artistName;
  final List<TrackModel> topTracks;

  const ArtistDetailScreen({
    Key? key,
    required this.artistName,
    this.topTracks = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(artistName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppColors.surfaceLight),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, AppColors.background],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Top Morceaux", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (topTracks.isNotEmpty) {
                            context.read<PlayerCubit>().playTrack(topTracks.first, queue: topTracks);
                          }
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("Écouter"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(120, 40),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: topTracks.length,
                    itemBuilder: (context, index) {
                      final track = topTracks[index];
                      return ListTile(
                        leading: Text("${index + 1}", style: const TextStyle(color: AppColors.textSecondary)),
                        title: Text(track.title, style: const TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: AppColors.primary),
                          onPressed: () => context.read<PlayerCubit>().playTrack(track, queue: topTracks),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
