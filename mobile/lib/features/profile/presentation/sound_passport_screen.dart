import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artist_name_display.dart';
import '../../../core/widgets/sonoritiz_artwork.dart';
import '../../../core/widgets/sonoritiz_dynamic_background.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../library/presentation/cubit/library_cubit.dart';
import '../../library/presentation/cubit/library_state.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/superlike_cubit.dart';

/// Sous-page Profil 1 : Passeport Sonore
/// Analyse ouverte et éditoriale de l'identité d'écoute réelle de l'utilisateur :
/// créneaux horaires favoris, indice de diversité, artistes piliers et titres repères.
class SoundPassportScreen extends StatelessWidget {
  const SoundPassportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final rawPlays = storage.getLifetimeTrackPlaysRaw();
    final followedArtists = storage.getFollowedArtists();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SonoritizDynamicBackground(
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<LibraryCubit, LibraryState>(
            builder: (context, libState) {
              final slState = context.watch<SuperlikeCubit>().state;
              final analysis = _SonicPassportAnalysis.compute(
                rawPlays: rawPlays,
                followedArtists: followedArtists,
                libState: libState,
                superlikeTracks: slState.tracks,
              );

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => context.pop(),
                          ),
                          const Expanded(
                            child: SonoritizPageTitle(
                              title: 'Passeport Sonore',
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 1. Synthèse éditoriale d'identité sonore
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SIGNATURE D’ÉCOUTE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            analysis.signatureLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            analysis.signatureSummary,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (analysis.signatureTracks.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: () {
                                context.read<PlayerCubit>().playTrack(
                                      analysis.signatureTracks.first,
                                      queue: analysis.signatureTracks,
                                      source: 'Mix Empreinte Sonore',
                                    );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 22,
                              ),
                              label: const Text(
                                'Lancer mon mix Empreinte',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Compteurs ouverts avec séparateurs fins
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MetricColumn(
                              value: '${analysis.totalPlays}',
                              label: 'Écoutes',
                            ),
                            _MetricColumn(
                              value: '${analysis.uniqueArtistsCount}',
                              label: 'Artistes',
                            ),
                            _MetricColumn(
                              value: '${analysis.diversityPercent}%',
                              label: 'Diversité',
                            ),
                            _MetricColumn(
                              value: analysis.avgDurationFormatted,
                              label: 'Durée moy.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Rythme de la journée (calculé sur play_timestamps)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Horloge d’écoute',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Répartition de vos sessions selon le moment de la journée',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.48),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ...analysis.timeSlots.map((slot) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _TimeSlotBar(slot: slot),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // 4. Artistes piliers
                  if (analysis.topArtists.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Artistes piliers',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Les signatures les plus présentes dans votre univers',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.48),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ...List.generate(analysis.topArtists.length, (i) {
                              final item = analysis.topArtists[i];
                              final isLast = i == analysis.topArtists.length - 1;
                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () => context.push(
                                      '/artist',
                                      extra: {
                                        'name': item.artistName,
                                        'imageUrl': item.coverUrl,
                                        'id': '',
                                      },
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 11,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 26,
                                            child: Text(
                                              '0${i + 1}',
                                              style: TextStyle(
                                                color: i == 0
                                                    ? AppColors.primary
                                                    : Colors.white
                                                        .withValues(alpha: 0.4),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          ClipOval(
                                            child: item.coverUrl.isNotEmpty
                                                ? SonoritizArtwork(
                                                    imageUrl: item.coverUrl,
                                                    width: 44,
                                                    height: 44,
                                                    borderRadius: 22,
                                                  )
                                                : Container(
                                                    width: 44,
                                                    height: 44,
                                                    color: const Color(0xFF1C1C22),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      item.artistName.isNotEmpty
                                                          ? item.artistName[0]
                                                              .toUpperCase()
                                                          : '?',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.artistName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${item.plays} écoute${item.plays > 1 ? 's' : ''}'
                                                  '${item.isFollowed ? ' · Suivi' : ''}',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.45),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: Colors.white
                                                .withValues(alpha: 0.3),
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    Divider(
                                      height: 1,
                                      color: Colors.white.withValues(alpha: 0.06),
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                  // 5. Titres repères
                  if (analysis.signatureTracks.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Titres repères',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ...List.generate(
                              analysis.signatureTracks.length,
                              (i) {
                                final track = analysis.signatureTracks[i];
                                final isLast =
                                    i == analysis.signatureTracks.length - 1;
                                return Column(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        context.read<PlayerCubit>().playTrack(
                                              track,
                                              queue: analysis.signatureTracks,
                                              source: 'Passeport Sonore',
                                            );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: SonoritizArtwork(
                                                imageUrl: track.coverUrl,
                                                width: 48,
                                                height: 48,
                                                borderRadius: 10,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    track.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  ArtistNameDisplay(
                                                    artistName: track.artistName,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(alpha: 0.5),
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.white
                                                  .withValues(alpha: 0.6),
                                              size: 22,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (!isLast)
                                      Divider(
                                        height: 1,
                                        color:
                                            Colors.white.withValues(alpha: 0.06),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 180)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String value;
  final String label;

  const _MetricColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TimeSlotBar extends StatelessWidget {
  final _TimeSlotStat slot;

  const _TimeSlotBar({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              slot.label,
              style: TextStyle(
                color: slot.isPeak
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.72),
                fontSize: 14,
                fontWeight: slot.isPeak ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              slot.hoursRange,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 12,
              ),
            ),
            const Spacer(),
            if (slot.isPeak && slot.count > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PIC',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Text(
              '${slot.percent}%',
              style: TextStyle(
                color: slot.isPeak
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.white.withValues(alpha: 0.08)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (slot.percent / 100.0).clamp(0.02, 1.0),
                  child: Container(
                    color: slot.isPeak
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeSlotStat {
  final String label;
  final String hoursRange;
  final int count;
  final int percent;
  final bool isPeak;

  const _TimeSlotStat({
    required this.label,
    required this.hoursRange,
    required this.count,
    required this.percent,
    required this.isPeak,
  });
}

class _ArtistScore {
  final String artistName;
  final int plays;
  final String coverUrl;
  final bool isFollowed;

  const _ArtistScore({
    required this.artistName,
    required this.plays,
    required this.coverUrl,
    required this.isFollowed,
  });
}

class _SonicPassportAnalysis {
  final int totalPlays;
  final int uniqueArtistsCount;
  final int diversityPercent;
  final String avgDurationFormatted;
  final String signatureLabel;
  final String signatureSummary;
  final List<_TimeSlotStat> timeSlots;
  final List<_ArtistScore> topArtists;
  final List<TrackModel> signatureTracks;

  const _SonicPassportAnalysis({
    required this.totalPlays,
    required this.uniqueArtistsCount,
    required this.diversityPercent,
    required this.avgDurationFormatted,
    required this.signatureLabel,
    required this.signatureSummary,
    required this.timeSlots,
    required this.topArtists,
    required this.signatureTracks,
  });

  factory _SonicPassportAnalysis.compute({
    required Map<String, dynamic> rawPlays,
    required List<String> followedArtists,
    required LibraryState libState,
    required List<TrackModel> superlikeTracks,
  }) {
    int totalPlays = 0;
    int totalDurationWeighted = 0;
    final Map<String, int> artistPlays = {};
    final Map<String, String> artistCovers = {};
    final List<MapEntry<int, TrackModel>> weightedTracks = [];
    final followedNormalized =
        followedArtists.map((e) => e.trim().toLowerCase()).toSet();

    int morningCount = 0; // 06-12
    int afternoonCount = 0; // 12-18
    int eveningCount = 0; // 18-23
    int nightCount = 0; // 23-06

    void bucketHour(DateTime? dt, int weight) {
      if (dt == null) return;
      final h = dt.toLocal().hour;
      if (h >= 6 && h < 12) {
        morningCount += weight;
      } else if (h >= 12 && h < 18) {
        afternoonCount += weight;
      } else if (h >= 18 && h < 23) {
        eveningCount += weight;
      } else {
        nightCount += weight;
      }
    }

    for (final entry in rawPlays.values) {
      if (entry is! Map) continue;
      final trackMap = entry['track'];
      if (trackMap is! Map) continue;
      final track = TrackModel.fromJson(Map<String, dynamic>.from(trackMap));
      final int count = (entry['count'] is int) ? entry['count'] as int : 1;
      if (count <= 0) continue;

      totalPlays += count;
      if (track.durationSeconds > 0) {
        totalDurationWeighted += track.durationSeconds * count;
      }

      weightedTracks.add(MapEntry(count, track));

      final artist = track.artistName.trim();
      if (artist.isNotEmpty) {
        artistPlays[artist] = (artistPlays[artist] ?? 0) + count;
        if ((artistCovers[artist] ?? '').isEmpty &&
            track.coverUrl.isNotEmpty) {
          artistCovers[artist] = track.coverUrl;
        }
      }

      final tsList = entry['play_timestamps'];
      if (tsList is List && tsList.isNotEmpty) {
        for (final rawTs in tsList) {
          bucketHour(DateTime.tryParse(rawTs.toString()), 1);
        }
      } else if (entry['last_played_at'] != null) {
        bucketHour(DateTime.tryParse(entry['last_played_at'].toString()), count);
      }
    }

    // Enrichir si peu d'écoutes locales via l'historique serveur
    if (libState is LibraryLoaded && totalPlays == 0) {
      for (final h in libState.history) {
        final t = h.track;
        if (t == null) continue;
        totalPlays++;
        if (t.durationSeconds > 0) totalDurationWeighted += t.durationSeconds;
        weightedTracks.add(MapEntry(1, t));
        if (t.artistName.trim().isNotEmpty) {
          artistPlays[t.artistName.trim()] =
              (artistPlays[t.artistName.trim()] ?? 0) + 1;
          artistCovers.putIfAbsent(t.artistName.trim(), () => t.coverUrl);
        }
        bucketHour(DateTime.tryParse(h.playedAt), 1);
      }
    }

    weightedTracks.sort((a, b) => b.key.compareTo(a.key));
    final List<TrackModel> signatureTracks = [];
    final seenTrackIds = <String>{};
    for (final item in [...weightedTracks.map((e) => e.value), ...superlikeTracks]) {
      final key = '${item.title.toLowerCase()}__${item.artistName.toLowerCase()}';
      if (seenTrackIds.add(key)) {
        signatureTracks.add(item);
        if (signatureTracks.length >= 6) break;
      }
    }

    final sortedArtists = artistPlays.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topArtists = sortedArtists.take(5).map((e) {
      return _ArtistScore(
        artistName: e.key,
        plays: e.value,
        coverUrl: artistCovers[e.key] ?? '',
        isFollowed: followedNormalized.contains(e.key.toLowerCase()),
      );
    }).toList();

    final int uniqueTracksCount = weightedTracks.length;
    final int uniqueArtistsCount = artistPlays.length;
    final int diversityPercent = uniqueTracksCount == 0
        ? 0
        : ((uniqueArtistsCount / uniqueTracksCount) * 100).round().clamp(12, 100);

    final int avgSecs =
        totalPlays > 0 ? (totalDurationWeighted / totalPlays).round() : 0;
    final int avgMin = avgSecs ~/ 60;
    final int avgRemSec = avgSecs % 60;
    final String avgDurationFormatted = avgSecs > 0
        ? '$avgMin:${avgRemSec.toString().padLeft(2, '0')}'
        : '--:--';

    final int totalBucketed =
        morningCount + afternoonCount + eveningCount + nightCount;
    final rawSlots = [
      ('Matin', '06h – 12h', morningCount),
      ('Après-midi', '12h – 18h', afternoonCount),
      ('Soirée', '18h – 23h', eveningCount),
      ('Nuit', '23h – 06h', nightCount),
    ];
    final int maxSlotCount =
        rawSlots.map((e) => e.$3).fold<int>(0, (a, b) => a > b ? a : b);

    final timeSlots = rawSlots.map((s) {
      final pct = totalBucketed > 0 ? ((s.$3 / totalBucketed) * 100).round() : 0;
      return _TimeSlotStat(
        label: s.$1,
        hoursRange: s.$2,
        count: s.$3,
        percent: pct,
        isPeak: maxSlotCount > 0 && s.$3 == maxSlotCount,
      );
    }).toList();

    String signatureLabel = 'Auditeur Explorateur';
    String signatureSummary =
        'Lancez quelques morceaux pour révéler votre empreinte rythmique et vos créneaux phares.';

    if (totalPlays > 0) {
      final peakSlot = timeSlots.firstWhere(
        (s) => s.isPeak,
        orElse: () => timeSlots.first,
      );
      if (nightCount >= maxSlotCount && nightCount > 0) {
        signatureLabel = 'Fréquence Nocturne';
      } else if (morningCount >= maxSlotCount && morningCount > 0) {
        signatureLabel = 'Éveil Mélodique';
      } else if (diversityPercent >= 65) {
        signatureLabel = 'Explorateur Curieux';
      } else {
        signatureLabel = 'Fidèle de Studio';
      }

      final topArtist = topArtists.isNotEmpty ? topArtists.first.artistName : '';
      signatureSummary = topArtist.isNotEmpty
          ? 'Votre créneau dominant est ${peakSlot.label.toLowerCase()} (${peakSlot.hoursRange}), porté par $topArtist avec un indice de diversité de $diversityPercent%.'
          : 'Vos sessions dominent en ${peakSlot.label.toLowerCase()} (${peakSlot.hoursRange}) avec $diversityPercent% de variété artistique.';
    }

    return _SonicPassportAnalysis(
      totalPlays: totalPlays,
      uniqueArtistsCount: uniqueArtistsCount,
      diversityPercent: diversityPercent,
      avgDurationFormatted: avgDurationFormatted,
      signatureLabel: signatureLabel,
      signatureSummary: signatureSummary,
      timeSlots: timeSlots,
      topArtists: topArtists,
      signatureTracks: signatureTracks,
    );
  }
}
