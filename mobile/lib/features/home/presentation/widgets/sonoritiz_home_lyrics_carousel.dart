import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart' show AudioPlayer;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../../core/services/palette_service.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/artist_name_display.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../library/presentation/cubit/library_cubit.dart';
import '../../../library/presentation/cubit/library_state.dart';
import '../../../player/data/models/lyrics_model.dart';
import '../../../player/data/models/track_model.dart';
import '../../../player/data/services/lyrics_service.dart';
import '../../../player/presentation/cubit/player_cubit.dart';
import '../../../player/presentation/cubit/player_state.dart';
import '../../../player/presentation/cubit/superlike_cubit.dart';
import '../../../player/presentation/cubit/superlike_state.dart';
import '../../../player/presentation/widgets/player_components/immersive_player_widgets.dart';

/// Rubrique Accueil « Sonoritiz Lyrics » :
/// - Sélectionne jusqu'à 10 sons parmi les sons aimés (Favoris) et Superlikés de l'utilisateur.
/// - Se renouvelle automatiquement tous les 5 jours.
/// - Long cadre rectangulaire (~88 % de la largeur) laissant apercevoir le prochain cadre à droite,
///   teinté avec la couleur dominante extraite de la pochette comme dans le lecteur.
/// - Paroles statiques au centre par défaut, qui deviennent dynamiques et synchronisées sur un
///   extrait de 30 secondes lorsqu'on appuie sur le bouton audio en bas à droite (en coupant tout son en cours).
class SonoritizHomeLyricsCarousel extends StatefulWidget {
  final List<TrackModel> fallbackFavorites;

  const SonoritizHomeLyricsCarousel({
    super.key,
    this.fallbackFavorites = const [],
  });

  @override
  State<SonoritizHomeLyricsCarousel> createState() =>
      _SonoritizHomeLyricsCarouselState();
}

class _SonoritizHomeLyricsCarouselState
    extends State<SonoritizHomeLyricsCarousel> {
  static const int _maxTracks = 10;
  static const int _refreshIntervalDays = 5;

  late final PageController _pageController;
  final ValueNotifier<String?> _activePlayingTrackId =
      ValueNotifier<String?>(null);

  List<TrackModel> _selectedTracks = const [];
  String _lastPoolSignature = '';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _activePlayingTrackId.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<TrackModel> _resolveTenFiveDayTracks({
    required List<TrackModel> superliked,
    required List<TrackModel> liked,
  }) {
    final List<TrackModel> pool = [];
    final Set<String> seenIds = {};

    for (final t in [...superliked, ...liked]) {
      final cleanId = t.id.trim();
      if (cleanId.isEmpty || t.isPodcastOrBook || t.title.trim().isEmpty) {
        continue;
      }
      if (seenIds.add(cleanId)) {
        pool.add(t);
      }
    }

    if (pool.isEmpty) return const [];

    final storage = StorageService();
    final cachedRaw = storage.getCachedSonoritizLyricsTracks();
    final cachedTs = storage.getSonoritizLyricsTimestamp();
    final now = DateTime.now();

    final bool cacheWithin5Days = cachedRaw != null &&
        cachedRaw.isNotEmpty &&
        cachedTs != null &&
        now.difference(cachedTs).inDays < _refreshIntervalDays;

    if (cacheWithin5Days) {
      final poolById = {for (final t in pool) t.id: t};
      final List<TrackModel> validCached = [];
      for (final raw in cachedRaw) {
        final parsed = TrackModel.fromJson(raw);
        // Conserver uniquement les sons toujours présents dans les aimés/superlikés
        if (poolById.containsKey(parsed.id)) {
          validCached.add(poolById[parsed.id]!);
        }
      }

      final int targetCount = math.min(_maxTracks, pool.length);
      if (validCached.length >= targetCount && validCached.isNotEmpty) {
        return validCached.take(_maxTracks).toList();
      }

      // Si l'utilisateur vient d'aimer de nouveaux sons et avait < 10 titres, compléter sans réinitialiser le cycle de 5 jours
      if (validCached.isNotEmpty) {
        final existingIds = validCached.map((t) => t.id).toSet();
        for (final candidate in pool) {
          if (validCached.length >= _maxTracks) break;
          if (existingIds.add(candidate.id)) {
            validCached.add(candidate);
          }
        }
        unawaited(
          storage.saveSonoritizLyricsTracks(
            validCached.map((e) => e.toJson()).toList(),
            updateTimestamp: false,
          ),
        );
        return validCached;
      }
    }

    // Nouveau cycle de 5 jours : sélectionner jusqu'à 10 sons aimés/superlikés
    final int cycleSeed =
        now.millisecondsSinceEpoch ~/ const Duration(days: 5).inMilliseconds;
    final shuffled = List<TrackModel>.from(pool)..shuffle(math.Random(cycleSeed));
    final chosen = shuffled.take(_maxTracks).toList();
    unawaited(
      storage.saveSonoritizLyricsTracks(
        chosen.map((e) => e.toJson()).toList(),
        updateTimestamp: true,
      ),
    );
    return chosen;
  }

  void _syncSelectionIfNeeded(
    List<TrackModel> superliked,
    List<TrackModel> liked,
  ) {
    final sig =
        '${superliked.map((e) => e.id).join(',')}|${liked.map((e) => e.id).join(',')}';
    if (sig == _lastPoolSignature && _selectedTracks.isNotEmpty) return;
    _lastPoolSignature = sig;
    _selectedTracks = _resolveTenFiveDayTracks(
      superliked: superliked,
      liked: liked,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlayerCubit, PlayerState>(
      listenWhen: (prev, cur) => !prev.isPlaying && cur.isPlaying,
      listener: (_, __) {
        // Si l'utilisateur lance un son depuis le lecteur principal, couper l'extrait Lyrics
        _activePlayingTrackId.value = null;
      },
      child: BlocBuilder<SuperlikeCubit, SuperlikeState>(
        builder: (context, slState) {
          List<TrackModel> liked = widget.fallbackFavorites;
          try {
            final libState = context.watch<LibraryCubit>().state;
            if (libState is LibraryLoaded && libState.favorites.isNotEmpty) {
              liked = libState.favorites;
            }
          } catch (_) {}

          _syncSelectionIfNeeded(slState.tracks, liked);
          if (_selectedTracks.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Sonoritiz Lyrics",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Découvrez les extraits lyrics de vos sons préférés",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 262,
                child: PageView.builder(
                  controller: _pageController,
                  padEnds: false,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (_) {
                    // Mettre en pause l'extrait précédent lorsqu'on glisse vers le cadre suivant
                    if (_activePlayingTrackId.value != null) {
                      _activePlayingTrackId.value = null;
                    }
                  },
                  itemCount: _selectedTracks.length,
                  itemBuilder: (context, index) {
                    final track = _selectedTracks[index];
                    final isLast = index == _selectedTracks.length - 1;
                    return Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? AppDimensions.spacingMd : 6,
                        right: isLast ? AppDimensions.spacingMd : 6,
                      ),
                      child: _SonoritizLyricsExcerptCard(
                        key: ValueKey('home_lyrics_${track.id}'),
                        track: track,
                        fullQueue: _selectedTracks,
                        activePlayingTrackId: _activePlayingTrackId,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXl),
            ],
          );
        },
      ),
    );
  }
}

class _SonoritizLyricsExcerptCard extends StatefulWidget {
  final TrackModel track;
  final List<TrackModel> fullQueue;
  final ValueNotifier<String?> activePlayingTrackId;

  const _SonoritizLyricsExcerptCard({
    super.key,
    required this.track,
    required this.fullQueue,
    required this.activePlayingTrackId,
  });

  @override
  State<_SonoritizLyricsExcerptCard> createState() =>
      _SonoritizLyricsExcerptCardState();
}

class _SonoritizLyricsExcerptCardState
    extends State<_SonoritizLyricsExcerptCard> {
  static const int _excerptDurationMs = 30000; // 30 secondes exactes
  static final LyricsService _lyricsService = LyricsService();

  ImmersivePalette _palette = ImmersivePalette.fallback;
  bool _loadingLyrics = true;
  bool _hasSyncedLrc = false;
  List<LrcLine> _excerptLines = const [];
  int _excerptStartMs = 0;

  AudioPlayer? _audioPlayer;
  YoutubeExplode? _yt;
  StreamSubscription<Duration>? _posSub;
  bool _audioReady = false;
  bool _loadingAudio = false;
  bool _isPlayingExcerpt = false;
  double _progress = 0.0;
  int _activeLineIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.activePlayingTrackId.addListener(_onGlobalActiveTrackChanged);
    _loadPalette();
    _loadLyricsExcerpt();
  }

  @override
  void didUpdateWidget(covariant _SonoritizLyricsExcerptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _stopExcerptAudio(resetVisual: true);
      _loadPalette();
      _loadLyricsExcerpt();
    }
  }

  @override
  void dispose() {
    widget.activePlayingTrackId.removeListener(_onGlobalActiveTrackChanged);
    _posSub?.cancel();
    _audioPlayer?.dispose();
    _yt?.close();
    super.dispose();
  }

  void _onGlobalActiveTrackChanged() {
    if (widget.activePlayingTrackId.value != widget.track.id &&
        (_isPlayingExcerpt || _loadingAudio)) {
      _stopExcerptAudio(resetVisual: false);
    }
  }

  Future<void> _loadPalette() async {
    final cached = PaletteService.getCached(widget.track.coverUrl);
    if (cached != null) {
      _palette = cached;
      if (mounted) setState(() {});
      return;
    }
    final extracted = await PaletteService.getPalette(widget.track.coverUrl);
    if (mounted) {
      setState(() => _palette = extracted);
    }
  }

  Future<void> _loadLyricsExcerpt() async {
    setState(() => _loadingLyrics = true);
    try {
      final model = await _lyricsService.getLyrics(
        widget.track.id,
        widget.track.artistName,
        widget.track.title,
        widget.track.durationSeconds,
      );
      if (!mounted) return;

      if (model != null && model.hasSynced) {
        final nonEmpty = model.parsedSyncedLyrics!
            .where((l) => l.text.trim().isNotEmpty && l.text.trim() != '♪')
            .toList();
        if (nonEmpty.isNotEmpty) {
          final int totalSec = widget.track.durationSeconds > 0
              ? widget.track.durationSeconds
              : (nonEmpty.last.time.inSeconds + 15);
          final int targetSec = totalSec > 50
              ? (totalSec * 0.28).round().clamp(16, totalSec - 34)
              : 0;

          int startIdx =
              nonEmpty.indexWhere((l) => l.time.inSeconds >= targetSec);
          if (startIdx < 0) {
            startIdx = (nonEmpty.length ~/ 4).clamp(0, nonEmpty.length - 1);
          }

          final int startMs = nonEmpty[startIdx].time.inMilliseconds;
          final int endMs = startMs + _excerptDurationMs;
          List<LrcLine> window = nonEmpty
              .skip(startIdx)
              .where((l) => l.time.inMilliseconds <= endMs + 2000)
              .toList();
          if (window.length < 4) {
            window = nonEmpty.skip(startIdx).take(6).toList();
          }

          setState(() {
            _hasSyncedLrc = true;
            _excerptStartMs = startMs;
            _excerptLines = window;
            _loadingLyrics = false;
          });
          return;
        }
      }

      if (model != null && model.hasPlain) {
        final rawLines = model.plainLyrics!
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !l.startsWith('['))
            .toList();
        if (rawLines.isNotEmpty) {
          final int startLine = rawLines.length > 8
              ? (rawLines.length ~/ 4).clamp(0, rawLines.length - 5)
              : 0;
          final slice = rawLines.skip(startLine).take(6).toList();
          final int baseMs = widget.track.durationSeconds > 50
              ? ((widget.track.durationSeconds * 0.28).round() * 1000)
              : 0;
          final int stepMs =
              (_excerptDurationMs ~/ math.max(1, slice.length));
          final synthetic = List.generate(
            slice.length,
            (i) => LrcLine(
              time: Duration(milliseconds: baseMs + (i * stepMs)),
              text: slice[i],
            ),
          );
          setState(() {
            _hasSyncedLrc = false;
            _excerptStartMs = baseMs;
            _excerptLines = synthetic;
            _loadingLyrics = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _hasSyncedLrc = false;
        _excerptStartMs = widget.track.durationSeconds > 50
            ? ((widget.track.durationSeconds * 0.28).round() * 1000)
            : 0;
        _excerptLines = [
          LrcLine(
            time: Duration(milliseconds: _excerptStartMs),
            text: "« ${widget.track.title} »",
          ),
          LrcLine(
            time: Duration(milliseconds: _excerptStartMs + 10000),
            text: "Appuyez sur l'audio pour écouter l'extrait de 30s",
          ),
        ];
        _loadingLyrics = false;
      });
    }
  }

  Future<void> _toggleExcerptAudio() async {
    HapticFeedback.lightImpact();

    if (_isPlayingExcerpt || _loadingAudio) {
      _stopExcerptAudio(resetVisual: false);
      if (widget.activePlayingTrackId.value == widget.track.id) {
        widget.activePlayingTrackId.value = null;
      }
      return;
    }

    // 1. Arrêter immédiatement tout son en cours sur le lecteur principal ET sur les autres cartes Lyrics
    PlayerCubit? playerCubit;
    try {
      playerCubit = context.read<PlayerCubit>();
      await playerCubit.pause();
    } catch (_) {}
    widget.activePlayingTrackId.value = widget.track.id;

    if (_audioReady && _audioPlayer != null) {
      final int currentRelMs =
          _audioPlayer!.position.inMilliseconds - _excerptStartMs;
      if (currentRelMs < 0 || currentRelMs >= _excerptDurationMs - 400) {
        await _audioPlayer!.seek(Duration(milliseconds: _excerptStartMs));
        _progress = 0.0;
        _activeLineIndex = 0;
      }
      setState(() => _isPlayingExcerpt = true);
      unawaited(_audioPlayer!.play());
      return;
    }

    setState(() {
      _loadingAudio = true;
      _activeLineIndex = 0;
      _progress = 0.0;
    });

    try {
      _audioPlayer ??= AudioPlayer(handleAudioSessionActivation: false);
      _yt ??= YoutubeExplode();

      String videoId = widget.track.id;
      final cachedVid = playerCubit?.getResolvedVideoId(widget.track.id);
      if (cachedVid != null && cachedVid.isNotEmpty) {
        videoId = cachedVid;
      }

      if (videoId.startsWith('deezer_') ||
          !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
        final results = await _yt!.search
            .search('${widget.track.artistName} ${widget.track.title} audio');
        if (results.isNotEmpty) {
          videoId = results.first.id.value;
          playerCubit?.seedResolvedVideoId(widget.track.id, videoId);
        }
      }

      if (!mounted ||
          widget.activePlayingTrackId.value != widget.track.id) {
        if (mounted) setState(() => _loadingAudio = false);
        return;
      }

      StreamManifest manifest;
      try {
        manifest = await _yt!.videos.streamsClient.getManifest(
          videoId,
          ytClients: [YoutubeApiClient.androidSdkless],
          requireWatchPage: false,
        );
      } catch (_) {
        manifest = await _yt!.videos.streamsClient.getManifest(videoId);
      }

      String audioUrl = '';
      String fallbackUrl = '';
      if (manifest.muxed.isNotEmpty) {
        audioUrl = manifest.muxed.withHighestBitrate().url.toString();
        if (manifest.audioOnly.isNotEmpty) {
          fallbackUrl = manifest.audioOnly.withHighestBitrate().url.toString();
        }
      } else if (manifest.audioOnly.isNotEmpty) {
        audioUrl = manifest.audioOnly.withHighestBitrate().url.toString();
      }

      if (audioUrl.isEmpty ||
          !mounted ||
          widget.activePlayingTrackId.value != widget.track.id) {
        if (mounted) setState(() => _loadingAudio = false);
        return;
      }

      try {
        await _audioPlayer!.setUrl(audioUrl);
      } catch (_) {
        if (fallbackUrl.isNotEmpty) {
          await _audioPlayer!.setUrl(fallbackUrl);
        } else {
          rethrow;
        }
      }

      if (!mounted ||
          widget.activePlayingTrackId.value != widget.track.id) {
        if (mounted) setState(() => _loadingAudio = false);
        return;
      }

      await _audioPlayer!.seek(Duration(milliseconds: _excerptStartMs));
      _posSub?.cancel();
      _posSub = _audioPlayer!.positionStream.listen(_onExcerptPositionTick);

      _audioReady = true;
      setState(() {
        _loadingAudio = false;
        _isPlayingExcerpt = true;
      });
      // Re-confirmer l'arrêt du lecteur principal juste avant le départ du flux
      try {
        await playerCubit?.pause();
      } catch (_) {}
      unawaited(_audioPlayer!.play());
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingAudio = false;
          _isPlayingExcerpt = false;
        });
      }
    }
  }

  void _onExcerptPositionTick(Duration pos) {
    if (!mounted || !_isPlayingExcerpt) return;
    final int posMs = pos.inMilliseconds;
    final int elapsedMs = (posMs - _excerptStartMs).clamp(0, _excerptDurationMs);

    if (posMs >= _excerptStartMs + _excerptDurationMs) {
      _stopExcerptAudio(resetVisual: true);
      if (widget.activePlayingTrackId.value == widget.track.id) {
        widget.activePlayingTrackId.value = null;
      }
      return;
    }

    int nextIdx = 0;
    if (_hasSyncedLrc && _excerptLines.isNotEmpty) {
      for (int i = 0; i < _excerptLines.length; i++) {
        if (posMs >= _excerptLines[i].time.inMilliseconds - 120) {
          nextIdx = i;
        } else {
          break;
        }
      }
    } else if (_excerptLines.isNotEmpty) {
      nextIdx = ((elapsedMs / _excerptDurationMs) * _excerptLines.length)
          .floor()
          .clamp(0, _excerptLines.length - 1);
    }

    final double nextProgress = elapsedMs / _excerptDurationMs;
    if ((nextProgress - _progress).abs() >= 0.015 ||
        nextIdx != _activeLineIndex) {
      setState(() {
        _progress = nextProgress;
        _activeLineIndex = nextIdx;
      });
    }
  }

  void _stopExcerptAudio({required bool resetVisual}) {
    _audioPlayer?.pause();
    if (resetVisual && _audioReady) {
      unawaited(
        _audioPlayer?.seek(Duration(milliseconds: _excerptStartMs)) ??
            Future.value(),
      );
    }
    if (mounted) {
      setState(() {
        _loadingAudio = false;
        _isPlayingExcerpt = false;
        if (resetVisual) {
          _progress = 0.0;
          _activeLineIndex = 0;
        }
      });
    }
  }

  Widget _buildCenterLyricsZone() {
    if (_loadingLyrics) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    if (_excerptLines.isEmpty) {
      return const SizedBox.shrink();
    }

    // Mode STATIQUE (tant qu'on n'a pas cliqué sur le bouton d'audio) :
    // affiche sobrement 4 lignes centrées de l'extrait lyrics.
    if (!_isPlayingExcerpt) {
      final staticPreview = _excerptLines.take(4).toList();
      return Padding(
        padding: const EdgeInsets.only(right: 54),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < staticPreview.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Text(
                  staticPreview[i].text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: i == 0 ? 0.94 : 0.78),
                    fontSize: 14.5,
                    fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                    height: 1.28,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Mode DYNAMIQUE (dès qu'on clique sur le bouton d'audio) :
    // fenêtre glissante synchronisée autour de la parole chantée à l'instant T !
    final int prevIdx = _activeLineIndex - 1;
    final int curIdx = _activeLineIndex.clamp(0, _excerptLines.length - 1);
    final int nextIdx = _activeLineIndex + 1;
    final int next2Idx = _activeLineIndex + 2;

    return Padding(
      padding: const EdgeInsets.only(right: 54),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 230),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.14),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: Column(
          key: ValueKey<int>(curIdx),
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (prevIdx >= 0 && prevIdx < _excerptLines.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _excerptLines[prevIdx].text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                _excerptLines[curIdx].text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  height: 1.24,
                  letterSpacing: -0.2,
                  shadows: [
                    Shadow(
                      color: Color(0x88000000),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            if (nextIdx < _excerptLines.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _excerptLines[nextIdx].text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (prevIdx < 0 && next2Idx < _excerptLines.length)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  _excerptLines[next2Idx].text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.36),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color topTint = Color.lerp(
          _palette.dominantColor,
          const Color(0xFF121216),
          0.18,
        ) ??
        _palette.dominantColor;
    final Color midTint = Color.lerp(
          _palette.midColor,
          const Color(0xFF0E0E12),
          0.25,
        ) ??
        _palette.midColor;
    final Color deepTint = _palette.deepColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            topTint,
            midTint,
            deepTint,
          ],
          stops: const [0.0, 0.54, 1.0],
        ),
        border: Border.all(
          color: _isPlayingExcerpt
              ? Colors.white.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.16),
          width: _isPlayingExcerpt ? 1.3 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _palette.dominantColor.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Excentré en haut à gauche : Pochette + Titre + Nom de l'artiste
              //    (Cliquer dessus coupe l'extrait 30s et lance le son complet dans le lecteur principal)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _stopExcerptAudio(resetVisual: true);
                        if (widget.activePlayingTrackId.value ==
                            widget.track.id) {
                          widget.activePlayingTrackId.value = null;
                        }
                        context.read<PlayerCubit>().playTrack(
                              widget.track,
                              queue: widget.fullQueue,
                              source: 'Sonoritiz Lyrics',
                            );
                      },
                      child: Row(
                        children: [
                          SonoritizArtwork(
                            imageUrl: widget.track.coverUrl,
                            width: 48,
                            height: 48,
                            borderRadius: 11,
                            cacheMaxDimension: 150,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                ArtistNameDisplay(
                                  artistName: widget.track.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.76),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      _isPlayingExcerpt
                          ? "${(30 - (_progress * 30).round()).clamp(0, 30)}s"
                          : "30s",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.90),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 2. Au centre du cadre : Paroles statiques -> dynamiques au clic sur l'audio
              Expanded(
                child: Center(
                  child: _buildCenterLyricsZone(),
                ),
              ),
            ],
          ),

          // 3. Excentré en bas à droite : Bouton d'audio (Play / Pause + progression 30s)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _toggleExcerptAudio,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isPlayingExcerpt)
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          value: _progress.clamp(0.0, 1.0),
                          strokeWidth: 2.6,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _isPlayingExcerpt
                            ? Colors.white
                            : Colors.black.withValues(alpha: 0.38),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.34),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.32),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _loadingAudio
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isPlayingExcerpt
                                    ? Icons.graphic_eq_rounded
                                    : Icons.volume_up_rounded,
                                size: 21,
                                color: _isPlayingExcerpt
                                    ? Colors.black
                                    : Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
