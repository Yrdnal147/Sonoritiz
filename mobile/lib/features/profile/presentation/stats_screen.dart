import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/share_card_generator.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../home/data/repositories/catalog_repository.dart';
import '../../library/data/repositories/library_repository.dart';
import '../../library/presentation/cubit/library_cubit.dart';
import '../../library/presentation/cubit/library_state.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/player_state.dart';

/// Écran Rétro & Statistiques Sonoritiz Wrapped
/// Design musical haut de gamme, typographie standard lisible, sans effet « template IA ».
class StatsScreen extends StatefulWidget {
  final bool openStoryOnInit;

  const StatsScreen({super.key, this.openStoryOnInit = false});

  static void showWrappedStory(
    BuildContext context, {
    required List<WrappedTrackItem> top10Tracks,
    required List<MapEntry<String, int>> topArtists,
    required int totalMinutes,
    required int totalPlays,
    required String personaTitle,
    required String personaSubtitle,
    required Map<String, String> artistImages,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Wrapped Story',
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) {
        return _WrappedStoryDialog(
          top10Tracks: top10Tracks,
          topArtists: topArtists,
          totalMinutes: totalMinutes,
          totalPlays: totalPlays,
          personaTitle: personaTitle,
          personaSubtitle: personaSubtitle,
          artistImages: artistImages,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  final CatalogRepository _catalogRepository = CatalogRepository();
  final Map<String, String> _artistImages = {};
  int _selectedPeriod = 0; // 0: Depuis la création, 1: 30 jours, 2: 7 jours
  bool _didAutoOpenStory = false;

  late AnimationController _vinylController;

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArtistPhotos();
    });
  }

  @override
  void dispose() {
    _vinylController.dispose();
    super.dispose();
  }

  Future<void> _loadArtistPhotos() async {
    final libCubit = context.read<LibraryCubit>();
    final top10 = libCubit.getTopTracksSinceCreation(limit: 10);
    final history = libCubit.state is LibraryLoaded
        ? (libCubit.state as LibraryLoaded).history
        : <HistoryModel>[];

    final artists = <String>{};
    for (final item in top10) {
      if (item.track.artistName.trim().isNotEmpty) {
        artists.add(item.track.artistName.trim());
      }
    }
    for (final h in history.take(30)) {
      final aName = h.track?.artistName.trim() ?? '';
      if (aName.isNotEmpty) {
        artists.add(aName);
      }
    }

    for (final name in artists.take(8)) {
      if (_artistImages.containsKey(name)) continue;
      try {
        final data = await _catalogRepository.getArtistDetailsDeezer(name);
        if (!mounted) return;
        final pic = (data['picture_xl'] ?? '').toString();
        if (pic.isNotEmpty) {
          setState(() {
            _artistImages[name] = pic;
          });
        }
      } catch (_) {}
    }
  }

  Map<String, String> _computePersona(
      int totalPlays, List<HistoryModel> history) {
    if (totalPlays >= 50) {
      return {
        'title': 'Légende Sonoritiz',
        'subtitle':
            'Votre passion façonne une collection musicale d’exception.',
      };
    }
    if (history.isNotEmpty) {
      int nightCount = 0;
      for (final h in history) {
        final dt = DateTime.tryParse(h.playedAt);
        if (dt != null) {
          final hour = dt.hour;
          if (hour >= 21 || hour <= 4) nightCount++;
        }
      }
      if (nightCount > history.length * 0.4) {
        return {
          'title': 'Vibrations Nocturnes',
          'subtitle':
              'Vos plus belles émotions musicales résonnent au cœur de la nuit.',
        };
      }
    }
    if (totalPlays >= 15) {
      return {
        'title': 'Mélomane Passionné',
        'subtitle':
            'Toujours à la découverte de nouveaux horizons et de pépites rares.',
      };
    }
    return {
      'title': 'Curateur Émergent',
      'subtitle':
          'Votre voyage musical sur Sonoritiz ne fait que commencer.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: BlocBuilder<LibraryCubit, LibraryState>(
        builder: (context, state) {
          final libCubit = context.read<LibraryCubit>();
          final int? filterDays =
              _selectedPeriod == 1 ? 30 : (_selectedPeriod == 2 ? 7 : null);
          final top10Wrapped =
              libCubit.getTopTracksForPeriod(days: filterDays, limit: 10);
          final rawHistory = state is LibraryLoaded
              ? state.history
              : const <HistoryModel>[];

          final now = DateTime.now();
          final filteredHistory = rawHistory.where((h) {
            final dt = DateTime.tryParse(h.playedAt);
            if (dt == null) return true;
            if (_selectedPeriod == 1) {
              return now.difference(dt).inDays <= 30;
            } else if (_selectedPeriod == 2) {
              return now.difference(dt).inDays <= 7;
            }
            return true;
          }).toList();

          int lifetimePlays = 0;
          int lifetimeSeconds = 0;
          for (final item in top10Wrapped) {
            lifetimePlays += item.playCount;
            final dur = item.track.durationSeconds > 0
                ? item.track.durationSeconds
                : 210;
            lifetimeSeconds += dur * item.playCount;
          }
          if (filteredHistory.length > lifetimePlays) {
            lifetimePlays = filteredHistory.length;
          }
          final totalMinutes = ((lifetimeSeconds > 0
                      ? lifetimeSeconds
                      : filteredHistory.length * 210) /
                  60)
              .round();
          final totalHours = (totalMinutes / 60).toStringAsFixed(1);

          final artistCounts = <String, int>{};
          for (final item in top10Wrapped) {
            final name = item.track.artistName.trim();
            if (name.isNotEmpty) {
              artistCounts[name] = (artistCounts[name] ?? 0) + item.playCount;
            }
          }
          for (final h in filteredHistory) {
            final name = h.track?.artistName.trim() ?? '';
            if (name.isNotEmpty && !artistCounts.containsKey(name)) {
              artistCounts[name] = (artistCounts[name] ?? 0) + 1;
            }
          }
          final sortedArtists = artistCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topArtists = sortedArtists.take(5).toList();

          final persona = _computePersona(lifetimePlays, rawHistory);

          if (widget.openStoryOnInit &&
              !_didAutoOpenStory &&
              top10Wrapped.isNotEmpty) {
            _didAutoOpenStory = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                StatsScreen.showWrappedStory(
                  context,
                  top10Tracks: top10Wrapped,
                  topArtists: topArtists,
                  totalMinutes: totalMinutes,
                  totalPlays: lifetimePlays,
                  personaTitle: persona['title']!,
                  personaSubtitle: persona['subtitle']!,
                  artistImages: _artistImages,
                );
              }
            });
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFF0C0C0E).withValues(alpha: 0.95),
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const SonoritizPageTitle(
                  title: 'Sonoritiz Wrapped',
                  fontSize: 22,
                ),
                actions: [
                  if (top10Wrapped.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            StatsScreen.showWrappedStory(
                              context,
                              top10Tracks: top10Wrapped,
                              topArtists: topArtists,
                              totalMinutes: totalMinutes,
                              totalPlays: lifetimePlays,
                              personaTitle: persona['title']!,
                              personaSubtitle: persona['subtitle']!,
                              artistImages: _artistImages,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD54F),
                                  Color(0xFFFF9800),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD54F)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                  color: Colors.black,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Story',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sélecteur de période
                      _buildPeriodSelector(),
                      const SizedBox(height: 24),

                      // Totem Sonore (Hero Card)
                      _buildHeroTotemCard(
                        totalMinutes: totalMinutes,
                        totalHours: totalHours,
                        lifetimePlays: lifetimePlays,
                        personaTitle: persona['title']!,
                        personaSubtitle: persona['subtitle']!,
                        topTrack:
                            top10Wrapped.isNotEmpty ? top10Wrapped.first : null,
                        onOpenStory: top10Wrapped.isEmpty
                            ? null
                            : () => StatsScreen.showWrappedStory(
                                  context,
                                  top10Tracks: top10Wrapped,
                                  topArtists: topArtists,
                                  totalMinutes: totalMinutes,
                                  totalPlays: lifetimePlays,
                                  personaTitle: persona['title']!,
                                  personaSubtitle: persona['subtitle']!,
                                  artistImages: _artistImages,
                                ),
                      ),
                      const SizedBox(height: 32),

                      // Podium des Artistes
                      if (topArtists.isNotEmpty) ...[
                        _buildSectionHeader(
                          icon: Icons.emoji_events_rounded,
                          title: 'Podium des Artistes',
                          subtitle: 'Les créateurs qui ont marqué vos journées',
                          accentColor: const Color(0xFFFFD54F),
                        ),
                        const SizedBox(height: 16),
                        _buildArtistsPodium(context, topArtists),
                        const SizedBox(height: 34),
                      ],

                      // Top 10 des Titres
                      _buildTop10Section(context, top10Wrapped),
                      const SizedBox(height: 34),

                      // Horloge musicale
                      _buildSectionHeader(
                        icon: Icons.schedule_rounded,
                        title: 'Horloge Musicale',
                        subtitle: 'Vos moments d’écoute favoris au fil du jour',
                        accentColor: AppColors.secondary,
                      ),
                      const SizedBox(height: 16),
                      _buildListeningRhythmCard(rawHistory),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const labels = [
      'Depuis la création',
      '30 derniers jours',
      '7 derniers jours',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = _selectedPeriod == i;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedPeriod = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFFFD54F), Color(0xFFFF9800)],
                        )
                      : null,
                  color:
                      isSelected ? null : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==========================================
  // TOTEM SONORE : HERO CARD
  // ==========================================
  Widget _buildHeroTotemCard({
    required int totalMinutes,
    required String totalHours,
    required int lifetimePlays,
    required String personaTitle,
    required String personaSubtitle,
    required WrappedTrackItem? topTrack,
    VoidCallback? onOpenStory,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2E1C44),
            const Color(0xFF171628),
            const Color(0xFF0F1B2A),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la carte avec vinyle en rotation
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vinyle d'or tournant
              RotationTransition(
                turns: _vinylController,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFF333333),
                        Color(0xFF111111),
                        Color(0xFF000000),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFD54F),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Center(
                    child: ClipOval(
                      child: topTrack != null &&
                              topTrack.track.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: topTrack.track.coverUrl,
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 34,
                              height: 34,
                              color: const Color(0xFFFFD54F),
                              child: const Icon(Icons.music_note_rounded,
                                  color: Colors.black, size: 18),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "L'ODYSSÉE SONORE",
                        style: TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      personaTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            personaSubtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),

          // Piliers de chiffres bien aérés
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeroMetric(
                  value: "$totalMinutes",
                  unit: "min",
                  label: "Temps d'écoute ($totalHours h)",
                  color: const Color(0xFFFFD54F),
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                _buildHeroMetric(
                  value: "$lifetimePlays",
                  unit: "titres",
                  label: "Morceaux écoutés",
                  color: AppColors.secondary,
                ),
              ],
            ),
          ),

          if (onOpenStory != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onOpenStory();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 6,
                ),
                icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
                label: const Text(
                  "Vivre mon Expérience Rétro",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required String value,
    required String unit,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PODIUM DES ARTISTES AVEC MÉDAILLONS RELIEF
  // ==========================================
  Widget _buildArtistsPodium(
    BuildContext context,
    List<MapEntry<String, int>> topArtists,
  ) {
    final first = topArtists.isNotEmpty ? topArtists[0] : null;
    final second = topArtists.length > 1 ? topArtists[1] : null;
    final third = topArtists.length > 2 ? topArtists[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second != null
                ? _buildPodiumColumn(
                    context: context,
                    rank: 2,
                    artistName: second.key,
                    plays: second.value,
                    avatarSize: 74,
                    badgeColor: const Color(0xFFE0E0E0),
                    label: "ARGENT",
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: first != null
                ? _buildPodiumColumn(
                    context: context,
                    rank: 1,
                    artistName: first.key,
                    plays: first.value,
                    avatarSize: 92,
                    badgeColor: const Color(0xFFFFD54F),
                    label: "OR #1",
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: third != null
                ? _buildPodiumColumn(
                    context: context,
                    rank: 3,
                    artistName: third.key,
                    plays: third.value,
                    avatarSize: 68,
                    badgeColor: const Color(0xFFFFB74D),
                    label: "BRONZE",
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required BuildContext context,
    required int rank,
    required String artistName,
    required int plays,
    required double avatarSize,
    required Color badgeColor,
    required String label,
  }) {
    final imageUrl = _artistImages[artistName] ?? '';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/artist', extra: {'name': artistName});
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 2.8),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _artistInitialAvatar(artistName),
                        )
                      : _artistInitialAvatar(artistName),
                ),
              ),
              Positioned(
                bottom: -10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$plays écoutes',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TOP 10 TITRES DEPUIS LA CRÉATION
  // ==========================================
  Widget _buildTop10Section(
    BuildContext context,
    List<WrappedTrackItem> top10,
  ) {
    final allTracks = top10.map((e) => e.track).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(
              icon: Icons.workspace_premium_rounded,
              title: 'Palmarès Top 10',
              subtitle: 'Vos morceaux cultes les plus réécoutés',
              accentColor: const Color(0xFFFFD54F),
            ),
            if (top10.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.read<PlayerCubit>().playTrack(
                        allTracks.first,
                        queue: allTracks,
                        source: 'votre Wrapped Top 10',
                      );
                },
                style: TextButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFFFD54F).withValues(alpha: 0.16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFFFFD54F), size: 18),
                label: const Text(
                  'Tout lire',
                  style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (top10.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Column(
              children: [
                Icon(Icons.music_note_rounded, size: 48, color: Colors.white38),
                SizedBox(height: 12),
                Text(
                  "Écoutez vos premiers morceaux pour débloquer votre Top 10 !",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          )
        else ...[
          // Titre #1 façon Single d'Or
          _buildNumberOneSpotlight(context, top10.first, allTracks),
          const SizedBox(height: 14),

          // Titres 2 à 10
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: BlocBuilder<PlayerCubit, PlayerState>(
              builder: (context, playerState) {
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: top10.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 20,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (context, index) {
                    final item = top10[index];
                    final rank = index + 1;
                    final isPlayingThis =
                        playerState.currentTrack?.id == item.track.id;

                    return _buildTrackRow(
                      context: context,
                      rank: rank,
                      item: item,
                      isCurrentTrack: isPlayingThis,
                      allTracks: allTracks,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNumberOneSpotlight(
    BuildContext context,
    WrappedTrackItem topItem,
    List<TrackModel> allTracks,
  ) {
    final track = topItem.track;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.read<PlayerCubit>().playTrack(
              track,
              queue: allTracks,
              source: 'votre Wrapped Top 10',
            );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFD54F).withValues(alpha: 0.22),
              const Color(0xFF281942),
              const Color(0xFF14141F),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
              blurRadius: 24,
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: track.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: track.coverUrl,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _fallbackCover(84),
                        )
                      : _fallbackCover(84),
                ),
                Positioned(
                  top: -8,
                  left: -8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD54F), Color(0xFFFF9800)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '#1 DISQUE D’OR',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${topItem.playCount} écoutes enregistrées',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFD54F),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackRow({
    required BuildContext context,
    required int rank,
    required WrappedTrackItem item,
    required bool isCurrentTrack,
    required List<TrackModel> allTracks,
  }) {
    final track = item.track;
    Color rankColor = Colors.white70;
    if (rank == 1) rankColor = const Color(0xFFFFD54F);
    if (rank == 2) rankColor = const Color(0xFFE0E0E0);
    if (rank == 3) rankColor = const Color(0xFFFFB74D);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<PlayerCubit>().playTrack(
              track,
              queue: allTracks,
              source: 'votre Wrapped Top 10',
            );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: track.coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: track.coverUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _fallbackCover(52),
                    )
                  : _fallbackCover(52),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrentTrack
                          ? const Color(0xFFFFD54F)
                          : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '×${item.playCount}',
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HORLOGE MUSICALE
  // ==========================================
  Widget _buildListeningRhythmCard(List<HistoryModel> history) {
    int morning = 0;
    int afternoon = 0;
    int evening = 0;
    int night = 0;

    for (final item in history) {
      final dt = DateTime.tryParse(item.playedAt);
      if (dt == null) continue;
      final h = dt.hour;
      if (h >= 6 && h < 12) {
        morning++;
      } else if (h >= 12 && h < 18) {
        afternoon++;
      } else if (h >= 18 && h < 23) {
        evening++;
      } else {
        night++;
      }
    }

    if (history.isEmpty) {
      morning = 4;
      afternoon = 8;
      evening = 14;
      night = 7;
    }

    final maxVal = [morning, afternoon, evening, night, 1]
        .reduce((a, b) => a > b ? a : b);

    final slots = [
      {
        'label': 'Aube & Matin',
        'sub': '06h - 12h',
        'val': morning,
        'icon': Icons.wb_sunny_rounded,
        'color': const Color(0xFFFFB74D),
      },
      {
        'label': 'Zénith & Après-midi',
        'sub': '12h - 18h',
        'val': afternoon,
        'icon': Icons.light_mode_rounded,
        'color': const Color(0xFFFF8A65),
      },
      {
        'label': 'Crépuscule & Soirée',
        'sub': '18h - 23h',
        'val': evening,
        'icon': Icons.nights_stay_rounded,
        'color': AppColors.primary,
      },
      {
        'label': 'Nuit Profonde',
        'sub': '23h - 06h',
        'val': night,
        'icon': Icons.dark_mode_rounded,
        'color': const Color(0xFFBA68C8),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        children: slots.map((s) {
          final val = s['val'] as int;
          final ratio = (val / maxVal).clamp(0.12, 1.0);
          final color = s['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(s['icon'] as IconData, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['label'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        s['sub'] as String,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 12,
                      color: Colors.white.withValues(alpha: 0.08),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$val',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallbackCover(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.white.withValues(alpha: 0.08),
      child: Icon(
        Icons.music_note_rounded,
        color: const Color(0xFFFFD54F),
        size: size * 0.45,
      ),
    );
  }

  Widget _artistInitialAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: Colors.white.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 26,
        ),
      ),
    );
  }
}

// ============================================================================
// STORY INTERACTIVE FULLSCREEN SONORITIZ (5 CHAPITRES & PARTAGE DIRECT)
// ============================================================================
class _WrappedStoryDialog extends StatefulWidget {
  final List<WrappedTrackItem> top10Tracks;
  final List<MapEntry<String, int>> topArtists;
  final int totalMinutes;
  final int totalPlays;
  final String personaTitle;
  final String personaSubtitle;
  final Map<String, String> artistImages;

  const _WrappedStoryDialog({
    required this.top10Tracks,
    required this.topArtists,
    required this.totalMinutes,
    required this.totalPlays,
    required this.personaTitle,
    required this.personaSubtitle,
    required this.artistImages,
  });

  @override
  State<_WrappedStoryDialog> createState() => _WrappedStoryDialogState();
}

class _WrappedStoryDialogState extends State<_WrappedStoryDialog>
    with SingleTickerProviderStateMixin {
  static const int _slideCount = 5;
  int _currentSlide = 0;
  late AnimationController _progressController;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextSlide();
        }
      });
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _nextSlide() {
    if (_currentSlide < _slideCount - 1) {
      setState(() => _currentSlide++);
      _progressController.forward(from: 0);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prevSlide() {
    if (_currentSlide > 0) {
      setState(() => _currentSlide--);
      _progressController.forward(from: 0);
    } else {
      _progressController.forward(from: 0);
    }
  }

  Future<void> _shareWrappedCard() async {
    _progressController.stop();
    setState(() => _isSharing = true);

    try {
      final topTracks = widget.top10Tracks
          .take(5)
          .map((e) => "${e.track.title} — ${e.track.artistName}")
          .toList();
      final topArtists = widget.topArtists.take(3).map((e) => e.key).toList();

      final cardFile = await ShareCardGenerator.generateWrappedShareCard(
        username: "Mélomane",
        personaTitle: widget.personaTitle,
        totalMinutes: widget.totalMinutes,
        totalPlays: widget.totalPlays,
        topTracks: topTracks,
        topArtists: topArtists,
      );

      if (cardFile != null && cardFile.existsSync()) {
        await Share.shareXFiles(
          [XFile(cardFile.path)],
          text:
              "Découvre mon Sonoritiz Wrapped ! 🎶 ${widget.totalMinutes} minutes de pure musique.",
        );
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
        _progressController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradients = [
      [const Color(0xFF2E1748), const Color(0xFF0F1018), const Color(0xFF0B1F2D)],
      [const Color(0xFF381F0E), const Color(0xFF141122), const Color(0xFF0B0C14)],
      [const Color(0xFF102830), const Color(0xFF16122C), const Color(0xFF0B0C14)],
      [const Color(0xFF28133C), const Color(0xFF0E1A30), const Color(0xFF0B0C14)],
      [const Color(0xFF341C52), const Color(0xFF1A1A2E), const Color(0xFF162A45)],
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onLongPressStart: (_) => _progressController.stop(),
        onLongPressEnd: (_) => _progressController.forward(),
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width * 0.35) {
            _prevSlide();
          } else {
            _nextSlide();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradients[_currentSlide % gradients.length],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Barres de progression de la Story
                  Row(
                    children: List.generate(_slideCount, (index) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 4.0,
                              child: AnimatedBuilder(
                                animation: _progressController,
                                builder: (context, _) {
                                  double val = 0.0;
                                  if (index < _currentSlide) {
                                    val = 1.0;
                                  } else if (index == _currentSlide) {
                                    val = _progressController.value;
                                  }
                                  return LinearProgressIndicator(
                                    value: val,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.25),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFFD54F),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // En-tête de la Story
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.album_rounded,
                                color: Color(0xFFFFD54F), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'SONORITIZ WRAPPED',
                              style: TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),

                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      child: _buildSlideContent(_currentSlide),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlideContent(int slideIndex) {
    switch (slideIndex) {
      case 0:
        return _buildSlide0Intro();
      case 1:
        return _buildSlide1Artist();
      case 2:
        return _buildSlide2Track();
      case 3:
        return _buildSlide3TopList();
      default:
        return _buildSlide4Share();
    }
  }

  // SLIDE 0 : INTRO EN CHIFFRES
  Widget _buildSlide0Intro() {
    return Column(
      key: const ValueKey('slide_0'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD54F), Color(0xFFFF9800)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
                blurRadius: 36,
              ),
            ],
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            color: Colors.black,
            size: 52,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          "VOTRE IDENTITÉ SONORE",
          style: TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.personaTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            widget.personaSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 42),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                children: [
                  Text(
                    "${widget.totalMinutes}",
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "MINUTES D'ÉCOUTE",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                width: 1,
                height: 48,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              Column(
                children: [
                  Text(
                    "${widget.totalPlays}",
                    style: const TextStyle(
                      color: Color(0xFFFF8A65),
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "TITRES JOUÉS",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // SLIDE 1 : ARTISTE #1
  Widget _buildSlide1Artist() {
    final topArtist =
        widget.topArtists.isNotEmpty ? widget.topArtists.first : null;
    final artistName = topArtist?.key ?? 'Votre Artiste Préféré';
    final plays = topArtist?.value ?? 0;
    final imageUrl = widget.artistImages[artistName] ?? '';

    return Column(
      key: const ValueKey('slide_1'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "VOTRE ARTISTE DE CŒUR",
          style: TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFD54F), width: 3.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
                blurRadius: 40,
              ),
            ],
          ),
          child: ClipOval(
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.white12,
                    child: const Icon(Icons.person,
                        size: 90, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          artistName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD54F)),
          ),
          child: Text(
            "$plays écoutes au total sur votre compte",
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // SLIDE 2 : TITRE #1
  Widget _buildSlide2Track() {
    if (widget.top10Tracks.isEmpty) return const SizedBox.shrink();
    final top1 = widget.top10Tracks.first;

    return Column(
      key: const ValueKey('slide_2'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "VOTRE HYMNE ABSOLU",
          style: TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: top1.track.coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: top1.track.coverUrl,
                    width: 230,
                    height: 230,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 230,
                    height: 230,
                    color: Colors.white12,
                    child: const Icon(Icons.music_note_rounded,
                        size: 90, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          top1.track.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          top1.track.artistName,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD54F)),
          ),
          child: Text(
            "Écouté ${top1.playCount} fois",
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // SLIDE 3 : TOP 5 LISTE
  Widget _buildSlide3TopList() {
    return Column(
      key: const ValueKey('slide_3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Center(
          child: Text(
            "VOS TITRES LES PLUS ÉCOUTÉS",
            style: TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: widget.top10Tracks.take(5).length,
            itemBuilder: (context, index) {
              final item = widget.top10Tracks[index];
              final rank = index + 1;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color:
                      Colors.white.withValues(alpha: rank == 1 ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: rank == 1
                        ? const Color(0xFFFFD54F).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        "#$rank",
                        style: TextStyle(
                          color: rank == 1
                              ? const Color(0xFFFFD54F)
                              : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item.track.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.track.coverUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: Colors.white12,
                              child: const Icon(Icons.music_note,
                                  color: Colors.white),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "×${item.playCount}",
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // SLIDE 4 : AFFICHE COLLECTOR & PARTAGE WHATSAPP / INSTAGRAM
  Widget _buildSlide4Share() {
    return Column(
      key: const ValueKey('slide_4'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF321A58),
                Color(0xFF161834),
                Color(0xFF0F263A),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
              width: 1.4,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.album_rounded,
                      color: Color(0xFFFFD54F), size: 22),
                  SizedBox(width: 8),
                  Text(
                    "SONORITIZ WRAPPED • OFFICIEL",
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                widget.personaTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    "${widget.totalMinutes} min d'écoute",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text("  •  ", style: TextStyle(color: Colors.white54)),
                  Text(
                    "${widget.totalPlays} titres joués",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "TOP 3 TITRES CULTES",
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.top10Tracks
                  .take(3)
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                final idx = entry.key + 1;
                final t = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    "$idx. ${t.track.title} — ${t.track.artistName}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Bouton de Partage WhatsApp / Instagram
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSharing ? null : _shareWrappedCard,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD54F),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 8,
            ),
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.share_rounded, size: 22),
            label: Text(
              _isSharing ? "Génération de l'affiche..." : "Partager ma Rétro",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
