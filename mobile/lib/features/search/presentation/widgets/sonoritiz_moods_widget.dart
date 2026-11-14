import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../core/widgets/sonoritiz_page_title.dart';
import '../../../home/domain/recommendation_engine.dart';
import '../../../home/presentation/cubit/home_cubit.dart';
import '../../../player/data/models/track_model.dart';
import '../../../player/presentation/cubit/player_cubit.dart';

typedef MoodPlaylistGenerator = Future<List<TrackModel>> Function(
  List<String> emotions,
);

/// Rubrique interactive Sonoritiz Moods intégrée à la page Recherche ou en plein écran.
///
/// L'utilisateur y retrouve les 10 émotions sous forme de bulles colorées flottantes.
/// Au 3e clic, les 3 bulles sélectionnées deviennent orange (texte noir) et
/// la playlist personnalisée (10 à 15 sons) s'affiche directement dessous.
class SonoritizMoodsWidget extends StatefulWidget {
  final MoodPlaylistGenerator? playlistGenerator;
  final bool showFullScreenButton;
  final double stageHeight;

  const SonoritizMoodsWidget({
    super.key,
    this.playlistGenerator,
    this.showFullScreenButton = true,
    this.stageHeight = 310,
  });

  @override
  State<SonoritizMoodsWidget> createState() => _SonoritizMoodsWidgetState();
}

class _SonoritizMoodsWidgetState extends State<SonoritizMoodsWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  final List<String> _selectedEmotions = [];
  List<TrackModel> _generatedTracks = [];
  bool _isGenerating = false;
  String? _errorText;
  int _generationToken = 0;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  void _onBubbleTap(MoodEmotionSpec spec) {
    final alreadyIdx = _selectedEmotions.indexOf(spec.label);
    setState(() {
      _errorText = null;
      if (alreadyIdx >= 0) {
        _selectedEmotions.removeAt(alreadyIdx);
        if (_selectedEmotions.length < 3) {
          _generatedTracks = [];
          _isGenerating = false;
          _generationToken++;
        }
      } else {
        if (_selectedEmotions.length >= 3) {
          _selectedEmotions.removeAt(0);
        }
        _selectedEmotions.add(spec.label);
      }
    });

    if (_selectedEmotions.length == 3) {
      unawaited(_generatePlaylistForSelection(List<String>.from(_selectedEmotions)));
    }
  }

  void _resetSelection() {
    setState(() {
      _generationToken++;
      _selectedEmotions.clear();
      _generatedTracks = [];
      _isGenerating = false;
      _errorText = null;
    });
  }

  Future<void> _generatePlaylistForSelection(List<String> emotions) async {
    final token = ++_generationToken;
    setState(() {
      _isGenerating = true;
      _errorText = null;
    });

    try {
      List<TrackModel> tracks;
      if (widget.playlistGenerator != null) {
        tracks = await widget.playlistGenerator!(emotions);
      } else {
        final homeCubit = context.read<HomeCubit>();
        final profile = homeCubit.buildUserTasteProfile();
        tracks = await homeCubit.catalogRepository.generateMoodEmotionPlaylist(
          emotions: emotions,
          profile: profile,
          minTracks: 10,
          maxTracks: 15,
        );
      }

      if (!mounted || token != _generationToken) return;
      setState(() {
        _generatedTracks = tracks.take(15).toList();
        _isGenerating = false;
        if (_generatedTracks.isEmpty) {
          _errorText =
              'Aucun titre trouvé pour cette combinaison. Essayez une autre nuance.';
        }
      });
    } catch (_) {
      if (!mounted || token != _generationToken) return;
      setState(() {
        _isGenerating = false;
        _errorText = 'Impossible de générer la playlist pour le moment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const emotions = RecommendationEngine.moodEmotions;
    final int remaining = math.max(0, 3 - _selectedEmotions.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: SonoritizPageTitle(
                  title: 'Sonoritiz Moods',
                  padding: EdgeInsets.zero,
                  fontSize: 22,
                ),
              ),
              if (widget.showFullScreenButton)
                TextButton.icon(
                  onPressed: () => context.push('/moods'),
                  icon: const Icon(
                    Icons.open_in_full_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Vue dédiée',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedEmotions.length == 3
                      ? 'Vos 3 émotions sont prêtes • Playlist générée ci-dessous'
                      : 'Choisissez $remaining émotion${remaining > 1 ? 's' : ''} parmi les bulles flottantes (${_selectedEmotions.length}/3)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_selectedEmotions.isNotEmpty)
                GestureDetector(
                  onTap: _resetSelection,
                  child: const Text(
                    'Réinitialiser',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Champ de bulles colorées flottantes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _FloatingEmotionsCanvas(
            height: widget.stageHeight,
            emotions: emotions,
            selectedLabels: _selectedEmotions,
            animation: _floatController,
            onTap: _onBubbleTap,
          ),
        ),

        // Playlist générée directement dès les 3 émotions sélectionnées
        if (_isGenerating)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Composition de votre playlist ${_selectedEmotions.join(' • ')}...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_errorText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              _errorText!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          )
        else if (_generatedTracks.isNotEmpty)
          _GeneratedMoodPlaylistPanel(
            emotions: _selectedEmotions,
            tracks: _generatedTracks,
          ),
      ],
    );
  }
}

class _FloatingEmotionsCanvas extends StatelessWidget {
  final double height;
  final List<MoodEmotionSpec> emotions;
  final List<String> selectedLabels;
  final Animation<double> animation;
  final ValueChanged<MoodEmotionSpec> onTap;

  // Positions relatives équilibrées (xFrac 0..1, yFrac 0..1, diamètre) pour 10 bulles sans chevauchement
  static const List<List<double>> _slots = [
    [0.16, 0.17, 78],  // Joie
    [0.48, 0.14, 82],  // Tristesse
    [0.81, 0.18, 84],  // Nostalgie
    [0.29, 0.42, 82],  // L'amour
    [0.64, 0.41, 84],  // Sérénité
    [0.13, 0.65, 84],  // Excitation
    [0.46, 0.65, 86],  // Mélancolie
    [0.82, 0.56, 76],  // Espoir
    [0.28, 0.86, 74],  // Colère
    [0.68, 0.85, 96],  // Émerveillement
  ];

  const _FloatingEmotionsCanvas({
    required this.height,
    required this.emotions,
    required this.selectedLabels,
    required this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = animation.value * 2 * math.pi;

              return Stack(
                clipBehavior: Clip.none,
                children: List.generate(emotions.length, (idx) {
                  final spec = emotions[idx];
                  final slot = _slots[idx % _slots.length];
                  final bool isSelected = selectedLabels.contains(spec.label);
                  final Color bubbleColor = isSelected
                      ? AppColors.primary
                      : Color(spec.bubbleColorHex);

                  final double baseDiameter = slot[2];
                  final double diameter =
                      w < 330 ? baseDiameter * 0.86 : baseDiameter;
                  final double dx = math.sin(t + idx * 1.15) * 5.5;
                  final double dy = math.cos(t * 0.85 + idx * 0.9) * 5.5;

                  final double cx =
                      (slot[0] * w).clamp(diameter / 2 + 6, w - diameter / 2 - 6) +
                          dx;
                  final double cy =
                      (slot[1] * h).clamp(diameter / 2 + 6, h - diameter / 2 - 6) +
                          dy;

                  return Positioned(
                    left: cx - diameter / 2,
                    top: cy - diameter / 2,
                    child: GestureDetector(
                      key: ValueKey('mood_bubble_${spec.id}'),
                      onTap: () => onTap(spec),
                      child: AnimatedScale(
                        scale: isSelected ? 1.09 : 1.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          width: diameter,
                          height: diameter,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.primary
                                : bubbleColor.withValues(alpha: 0.24),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : bubbleColor.withValues(alpha: 0.85),
                              width: isSelected ? 2.4 : 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 2),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.black,
                                    size: 14,
                                  ),
                                ),
                              Text(
                                spec.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: spec.label.length > 10 ? 10.5 : 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          );
        },
      ),
    );
  }
}

class _GeneratedMoodPlaylistPanel extends StatelessWidget {
  final List<String> emotions;
  final List<TrackModel> tracks;

  const _GeneratedMoodPlaylistPanel({
    required this.emotions,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    final String sourceLabel = 'Moods • ${emotions.join(', ')}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emotions.join(' • '),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tracks.length} titres sélectionnés selon vos goûts',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  context.read<PlayerCubit>().playTrack(
                        tracks.first,
                        queue: tracks,
                        source: sourceLabel,
                      );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Colors.black, size: 19),
                      SizedBox(width: 4),
                      Text(
                        'Tout lire',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tracks.length,
            separatorBuilder: (_, __) => Divider(
              color: Colors.white.withValues(alpha: 0.06),
              height: 10,
            ),
            itemBuilder: (context, index) {
              final track = tracks[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: SonoritizArtwork(
                  imageUrl: track.coverUrl,
                  width: 46,
                  height: 46,
                  borderRadius: 10,
                ),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12.5,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  onPressed: () {
                    context.read<PlayerCubit>().playTrack(
                          track,
                          queue: tracks,
                          source: sourceLabel,
                        );
                  },
                ),
                onTap: () {
                  context.read<PlayerCubit>().playTrack(
                        track,
                        queue: tracks,
                        source: sourceLabel,
                      );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
