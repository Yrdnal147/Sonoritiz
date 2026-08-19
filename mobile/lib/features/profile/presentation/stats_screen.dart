import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../library/presentation/cubit/library_cubit.dart';
import '../../library/presentation/cubit/library_state.dart';
import '../../player/data/models/track_model.dart';
import '../../../core/widgets/festive_background.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _topArtist = "Aucun";
  TrackModel? _topTrack;
  int _totalPlays = 0;
  bool _calculating = true;

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  void _calculateStats() {
    final state = context.read<LibraryCubit>().state;
    if (state is LibraryLoaded) {
      final history = state.history;
      _totalPlays = history.length;

      if (_totalPlays > 0) {
        final Map<String, int> artistCounts = {};
        final Map<String, int> trackCounts = {};
        final Map<String, TrackModel> trackMap = {};

        for (var h in history) {
          if (h.track != null) {
            final artist = h.track!.artistName;
            final trackId = h.track!.id;
            artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
            trackCounts[trackId] = (trackCounts[trackId] ?? 0) + 1;
            trackMap[trackId] = h.track!;
          }
        }

        if (artistCounts.isNotEmpty) {
          _topArtist = artistCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        }

        if (trackCounts.isNotEmpty) {
          final topTrackId = trackCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
          _topTrack = trackMap[topTrackId];
        }
      }
    }
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _calculating = false;
        });
      }
    });
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required int delay,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
              const SizedBox(width: 12),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.2, end: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Vos Statistiques", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: _calculating
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : FestiveBackground(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Replay",
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ).animate().fadeIn().scale(alignment: Alignment.centerLeft),
                        const SizedBox(height: 8),
                        Text(
                          "Vos habitudes d'écoute en un clin d'œil.",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 40),
                        
                        _buildStatCard(
                          title: "Top Artiste",
                          value: _topArtist,
                          subtitle: "Vous ne vous en lassez pas.",
                          icon: Icons.mic_rounded,
                          gradientColors: [const Color(0xFFFF5E5B), const Color(0xFFFF9B85)],
                          delay: 400,
                        ),
                        
                        _buildStatCard(
                          title: "Titre Phare",
                          value: _topTrack?.title ?? "Aucun titre",
                          subtitle: _topTrack?.artistName ?? "Commencez à écouter de la musique !",
                          icon: Icons.local_fire_department_rounded,
                          gradientColors: [const Color(0xFF8A84E2), const Color(0xFFB3B0ED)],
                          delay: 600,
                        ),
                        
                        _buildStatCard(
                          title: "Volume Total",
                          value: "$_totalPlays",
                          subtitle: "morceaux écoutés au total.",
                          icon: Icons.headphones_rounded,
                          gradientColors: [const Color(0xFF4CAF50), const Color(0xFF81C784)],
                          delay: 800,
                        ),
                        
                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            "Continuez d'explorer la musique !",
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold),
                          ),
                        ).animate().fadeIn(delay: 1000.ms),
                        const SizedBox(height: 40),
                      ],
                  ),
                ),
              ),
            ),
    );
  }
}
