import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../features/offline/data/repositories/offline_repository.dart';
import '../constants/api_constants.dart';
import '../storage/storage_service.dart';

/// Lien de streaming résolu, avec sa date de résolution (les liens YouTube expirent).
class _CachedStreamUrl {
  final String url;
  final DateTime resolvedAt;
  _CachedStreamUrl(this.url) : resolvedAt = DateTime.now();
}

class SonoritizAudioHandler extends BaseAudioHandler with SeekHandler {
  static bool get _isAndroidNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final AndroidEqualizer? _equalizer =
      _isAndroidNative ? AndroidEqualizer() : null;
  late final AudioPlayer _player = _isAndroidNative
      ? AudioPlayer(
          audioPipeline: AudioPipeline(
            androidAudioEffects: [_equalizer!],
          ),
          handleInterruptions: true,
          androidApplyAudioAttributes: true,
          handleAudioSessionActivation: true,
          audioLoadConfiguration: const AudioLoadConfiguration(
            androidLoadControl: AndroidLoadControl(
              minBufferDuration: Duration(seconds: 60),
              maxBufferDuration: Duration(seconds: 180),
              bufferForPlaybackDuration: Duration(milliseconds: 250),
              bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 1000),
              backBufferDuration: Duration(seconds: 30),
            ),
          ),
        )
      : AudioPlayer(
          handleInterruptions: true,
          handleAudioSessionActivation: true,
        );
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 45),
  ));
  final OfflineRepository? offlineRepository;

  AudioPlayer get player => _player;

  // Niveau d'atténuation vocale (0.0 = original, 1.0 = instrumentale pure)
  double _vocalAttenuationLevel = 0.0;
  double get vocalAttenuationLevel => _vocalAttenuationLevel;

  Future<void> setVocalAttenuation(double level) async {
    final clamped = level.clamp(0.0, 1.0);
    _vocalAttenuationLevel = clamped;

    final equalizer = _equalizer;
    if (!_isAndroidNative || equalizer == null) return;

    try {
      if (clamped <= 0.01) {
        await applyUserAudioSettings();
        return;
      }

      if (!equalizer.enabled) {
        await equalizer.setEnabled(true);
      }

      final params = await equalizer.parameters;
      for (final band in params.bands) {
        final freq = band.centerFrequency;
        // Atténuation ciblée sur les formants vocaux (400 Hz à 4500 Hz)
        if (freq >= 400 && freq <= 4500) {
          final targetGain = params.minDecibels * clamped;
          await band.setGain(targetGain);
        } else {
          // Préservation de l'impact de la basse et du groove
          await band.setGain(0.0);
        }
      }
    } catch (e) {
      debugPrint('[SonoritizAudioHandler] Vocal attenuation warning: $e');
    }
  }

  /// Vide le cache d'URL de flux (ex: après changement de qualité de streaming)
  /// et réapplique le profil acoustique et la normalisation choisis.
  Future<void> applyUserAudioSettings({bool clearResolvedStreams = false}) async {
    if (clearResolvedStreams) {
      _streamUrlCache.clear();
    }

    try {
      final storage = StorageService();
      final normalize = storage.volumeNormalizationEnabled;
      await _player.setVolume(normalize ? 0.92 : 1.0);

      if (_vocalAttenuationLevel > 0.01) return;
      final equalizer = _equalizer;
      if (!_isAndroidNative || equalizer == null) return;

      final preset = storage.audioPreset;
      if (preset == 'Studio') {
        if (equalizer.enabled) {
          final params = await equalizer.parameters;
          for (final band in params.bands) {
            await band.setGain(0.0);
          }
          await equalizer.setEnabled(false);
        }
        return;
      }

      if (!equalizer.enabled) {
        await equalizer.setEnabled(true);
      }
      final params = await equalizer.parameters;
      final maxDb = params.maxDecibels;
      final minDb = params.minDecibels;

      for (final band in params.bands) {
        final f = band.centerFrequency;
        double ratio = 0.0;
        switch (preset) {
          case 'Bass Boost':
            if (f <= 250) {
              ratio = 0.55;
            } else if (f <= 700) {
              ratio = -0.10;
            } else if (f >= 6000) {
              ratio = 0.20;
            }
            break;
          case 'Vocal Clair':
            if (f < 180) {
              ratio = -0.25;
            } else if (f >= 800 && f <= 4500) {
              ratio = 0.45;
            } else if (f > 4500) {
              ratio = 0.15;
            }
            break;
          case 'Acoustique':
            if (f >= 180 && f <= 600) {
              ratio = 0.25;
            } else if (f >= 3500) {
              ratio = 0.35;
            }
            break;
          case 'Club & Urbain':
            if (f <= 220) {
              ratio = 0.60;
            } else if (f >= 500 && f <= 2000) {
              ratio = -0.12;
            } else if (f >= 4500) {
              ratio = 0.40;
            }
            break;
          case 'Nuit Douce':
            if (f <= 120) {
              ratio = -0.15;
            } else if (f >= 3000) {
              ratio = -0.35;
            }
            break;
        }
        final gain = ratio >= 0 ? (maxDb * ratio) : (minDb.abs() * ratio);
        await band.setGain(gain.clamp(minDb, maxDb));
      }
    } catch (e) {
      debugPrint('[SonoritizAudioHandler] applyUserAudioSettings warning: $e');
    }
  }

  // Callback pour toggler les favoris depuis la notification ou le widget
  void Function(String trackId)? onToggleFavorite;
  // Callback pour toggler le mode répéter depuis le widget
  void Function()? onToggleRepeat;
  // Callback pour ouvrir Connect depuis la notification
  void Function()? onOpenConnect;
  // Callback en cas d'erreur de lecture
  void Function(String trackId, String error)? onPlaybackError;
  // Callbacks pour les actions Suivant / Précédent depuis la notification
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  // État de réaction (Like / Superlike) du morceau actuel
  bool _isFavorite = false;
  bool _isSuperliked = false;

  void updateReactionState({required bool isFavorite, required bool isSuperliked}) {
    if (_isFavorite == isFavorite && _isSuperliked == isSuperliked) return;
    _isFavorite = isFavorite;
    _isSuperliked = isSuperliked;
    _broadcastPlaybackState();
  }

  /// Les liens de stream YouTube expirent (~6h). On les garde 2h30 par sécurité.
  static const Duration _streamUrlTtl = Duration(hours: 2, minutes: 30);

  /// Numéro de la dernière demande de lecture.
  int _playRequestId = 0;

  /// Empêche une boucle infinie de récupération sur un même morceau en erreur réseau.
  String? _recoveringTrackId;

  /// Dernière position valide connue pour reprendre après une micro-coupure réseau.
  Duration _lastKnownPosition = Duration.zero;

  /// Cache ID du morceau -> ID vidéo YouTube (11 caractères).
  final Map<String, String> _videoIdCache = {};

  /// Cache ID du son -> lien de stream résolu.
  final Map<String, _CachedStreamUrl> _streamUrlCache = {};

  /// Résolutions en cours, pour éviter de chercher deux fois le même son.
  final Map<String, Future<String>> _inflightResolutions = {};

  /// Indique si un son est en cours de préparation.
  final StreamController<bool> _resolvingController = StreamController<bool>.broadcast();
  bool _isResolving = false;
  Stream<bool> get resolvingStream => _resolvingController.stream;
  bool get isResolving => _isResolving;

  static final RegExp _youtubeIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');

  SonoritizAudioHandler({this.offlineRepository}) {
    _configurePlayerDefaults();
    _initPlayerListeners();
  }

  Future<void> _configurePlayerDefaults() async {
    try {
      // Toujours laisser PlayerCubit piloter la file d'attente complète (LoopMode.off côté ExoPlayer).
      await _player.setLoopMode(LoopMode.off);
    } catch (e) {
      debugPrint('Player default setup warning: $e');
    }
  }

  void _initPlayerListeners() {
    _player.positionStream.listen((pos) {
      if (!_isResolving && pos > Duration.zero) {
        _lastKnownPosition = pos;
      }
    });

    _player.playbackEventStream.listen((PlaybackEvent event) {
      _broadcastPlaybackState(event);
    }, onError: (Object e, StackTrace stackTrace) {
      debugPrint('====== JUST AUDIO ASYNC ERROR ======');
      debugPrint('Error: $e');
      debugPrint('====================================');
      _setResolving(false);

      final currentItem = mediaItem.value;
      if (currentItem != null && _recoveringTrackId != currentItem.id) {
        _recoveringTrackId = currentItem.id;
        unawaited(_recoverFromStreamInterruption(currentItem, e));
      } else if (currentItem != null) {
        _recoveringTrackId = null;
        onPlaybackError?.call(currentItem.id, e.toString());
      }
    });

    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null && duration > Duration.zero) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });
  }

  Future<void> _recoverFromStreamInterruption(MediaItem item, Object cause) async {
    final resumePos = _lastKnownPosition;
    _streamUrlCache.remove(item.id);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mediaItem.value?.id != item.id) return;
      await playTrack(item, resumePosition: resumePos);
      _recoveringTrackId = null;
    } catch (_) {
      _recoveringTrackId = null;
      if (mediaItem.value?.id == item.id) {
        onPlaybackError?.call(item.id, cause.toString());
      }
    }
  }

  void _broadcastPlaybackState([PlaybackEvent? event]) {
    final bool effectivePlaying = _isResolving ? true : _player.playing;
    final AudioProcessingState effectiveProcessingState = _isResolving
        ? AudioProcessingState.loading
        : const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!;

    MediaControl reactionControl;
    if (_isSuperliked) {
      reactionControl = MediaControl.custom(
        androidIcon: 'drawable/ic_superlike',
        label: 'Superlike',
        name: 'toggleFavorite',
      );
    } else if (_isFavorite) {
      reactionControl = MediaControl.custom(
        androidIcon: 'drawable/ic_favorite',
        label: 'Favori',
        name: 'toggleFavorite',
      );
    } else {
      reactionControl = MediaControl.custom(
        androidIcon: 'drawable/ic_favorite_border',
        label: "J'aime",
        name: 'toggleFavorite',
      );
    }

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (effectivePlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          reactionControl,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.playPause,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: effectiveProcessingState,
        playing: effectivePlaying,
        updatePosition: _isResolving ? Duration.zero : _player.position,
        bufferedPosition: _isResolving ? Duration.zero : _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event?.currentIndex ?? _player.currentIndex,
      ),
    );
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'toggleFavorite') {
      final currentItem = mediaItem.value;
      if (currentItem != null && onToggleFavorite != null) {
        onToggleFavorite!(currentItem.id);
      }
    } else if (name == 'toggleRepeat') {
      onToggleRepeat?.call();
    } else if (name == 'openConnect') {
      onOpenConnect?.call();
    }
    return super.customAction(name, extras);
  }

  void _setResolving(bool value) {
    if (_isResolving == value) return;
    _isResolving = value;
    _resolvingController.add(value);
    _broadcastPlaybackState();
  }

  Future<void> playTrack(
    MediaItem item, {
    bool preferMuxed = true,
    Duration? resumePosition,
  }) async {
    final requestId = ++_playRequestId;
    bool isStale() => requestId != _playRequestId;

    if (resumePosition == null) {
      _lastKnownPosition = Duration.zero;
      _recoveringTrackId = null;
    }

    debugPrint('[playback] start track=${item.id} (${item.title} - ${item.artist})');
    mediaItem.add(item);
    _setResolving(true);

    try {
      if (_player.playing) {
        await _player.pause();
      }
    } catch (_) {}

    try {
      // 1. Fichier déjà téléchargé hors-ligne ? (hors navigateur Web)
      if (!kIsWeb && offlineRepository != null) {
        final offlineTrack = offlineRepository!.getOfflineTrack(item.id);
        if (offlineTrack != null && await File(offlineTrack.localAudioPath).exists()) {
          debugPrint('Playing OFFLINE file: ${offlineTrack.localAudioPath}');
          if (offlineTrack.localCoverPath.isNotEmpty &&
              await File(offlineTrack.localCoverPath).exists()) {
            mediaItem.add(item.copyWith(artUri: Uri.file(offlineTrack.localCoverPath)));
          }
          await _player.setAudioSource(
            AudioSource.uri(Uri.file(offlineTrack.localAudioPath)),
            initialPosition: resumePosition,
          );
          if (isStale()) return;
          _setResolving(false);
          unawaited(_player.play());
          return;
        }
      }

      // 2. Fichier local sur l'appareil ?
      final String rawExtraAudioUrl = (item.extras?['audio_url'] ?? '').toString();
      String audioUrl = rawExtraAudioUrl;
      if (audioUrl.contains('dzcdn.net') || audioUrl.contains('preview')) {
        audioUrl = '';
      }

      if (!kIsWeb && (audioUrl.startsWith('file://') || item.id.startsWith('local_'))) {
        final localPath = audioUrl.replaceFirst('file://', '');
        debugPrint('Playing LOCAL file: $localPath');
        await _player.setAudioSource(
          AudioSource.uri(Uri.file(localPath)),
          initialPosition: resumePosition,
        );
        if (isStale()) return;
        _setResolving(false);
        unawaited(_player.play());
        return;
      }

      // 3. Extraction directe du morceau complet YouTube (flux Muxed MP4 itag 18, 3 à 5 min)
      if (kIsWeb) {
        audioUrl = await _resolveWebStreamUrl(item);
      } else if (audioUrl.isEmpty && item.id.isNotEmpty) {
        audioUrl = await _resolveStreamUrl(item);
      }
      if (isStale()) return;

      if (audioUrl.isEmpty) {
        throw Exception("Impossible d'extraire le flux audio pour ${item.title}");
      }

      debugPrint('[playback] Playing Muxed Stream URL for ${item.title}...');
      try {
        await _player
            .setAudioSource(
              AudioSource.uri(Uri.parse(audioUrl)),
              initialPosition: resumePosition,
            )
            .timeout(Duration(seconds: kIsWeb ? 8 : 12));
      } catch (directError) {
        if (isStale()) return;
        if (kIsWeb) {
          final backendProxyUrl = _buildBackendYoutubeStreamUrl(item);
          if (backendProxyUrl.isNotEmpty && backendProxyUrl != audioUrl) {
            await _player
                .setAudioSource(
                  AudioSource.uri(Uri.parse(backendProxyUrl)),
                  initialPosition: resumePosition,
                )
                .timeout(const Duration(seconds: 10));
          } else {
            rethrow;
          }
        } else {
          debugPrint('[playback] Direct ExoPlayer URI failed ($directError), using Dio local stream cache fallback...');
          final tempDir = await getTemporaryDirectory();
          final safeId = item.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final partFile = File('${tempDir.path}/stream_cache_$safeId.part');
          final tempFile = File('${tempDir.path}/stream_cache_$safeId.mp4');
          if (await partFile.exists()) {
            try {
              await partFile.delete();
            } catch (_) {}
          }
          await _dio.download(audioUrl, partFile.path);
          if (isStale()) return;
          if (await tempFile.exists()) {
            try {
              await tempFile.delete();
            } catch (_) {}
          }
          await partFile.rename(tempFile.path);
          await _player.setAudioSource(
            AudioSource.uri(Uri.file(tempFile.path)),
            initialPosition: resumePosition,
          );
        }
      }
      if (isStale()) return;

      _setResolving(false);
      unawaited(_player.play());
    } on PlayerInterruptedException {
      // Chargement interrompu par un changement de morceau : normal.
    } catch (e, stack) {
      debugPrint('Audio playback error: $e\n$stack');
      _streamUrlCache.remove(item.id);
      if (!isStale()) {
        _setResolving(false);
        onPlaybackError?.call(item.id, e.toString());
      }
    } finally {
      if (!isStale() && _isResolving) {
        _setResolving(false);
      }
    }
  }

  /// Prépare un MediaItem au repos (ex: restauration du dernier son dans le mini-lecteur)
  /// sans démarrer la lecture ni prendre le focus audio.
  void prepareIdleMediaItem(MediaItem item) {
    if (_isResolving || _player.playing) return;
    mediaItem.add(item);
  }

  /// Prépare à l'avance le lien du son suivant dans la file.
  /// Ne s'exécute jamais si un morceau demandé par l'utilisateur est en train de charger.
  Future<void> prefetch(MediaItem item) async {
    try {
      if (_isResolving) return;
      final rawUrl = (item.extras?['audio_url'] ?? '').toString();
      if (rawUrl.startsWith('file://')) return;
      if (item.id.isEmpty || item.id.startsWith('local_')) return;
      if (offlineRepository?.getOfflineTrack(item.id) != null) return;
      if (kIsWeb) {
        await _resolveWebStreamUrl(item);
      } else {
        await _resolveStreamUrl(item);
      }
    } catch (_) {}
  }

  Future<void> reportPlaybackStall(String trackId, {Object? cause}) async {
    final item = mediaItem.value;
    if (item == null || item.id != trackId) return;

    // 1ère tentative : relancer automatiquement le flux à la position courante
    if (_recoveringTrackId != trackId) {
      _recoveringTrackId = trackId;
      await _recoverFromStreamInterruption(item, cause ?? 'Playback stalled.');
      return;
    }

    _recoveringTrackId = null;
    _playRequestId++;
    _streamUrlCache.remove(trackId);
    _setResolving(false);
    try {
      await _player.stop();
    } catch (_) {}
    onPlaybackError?.call(
      trackId,
      cause?.toString() ?? 'Playback stalled.',
    );
  }

  Future<String> _resolveStreamUrl(MediaItem item) {
    final cached = _streamUrlCache[item.id];
    if (cached != null && DateTime.now().difference(cached.resolvedAt) < _streamUrlTtl) {
      return Future.value(cached.url);
    }
    final inflight = _inflightResolutions[item.id];
    if (inflight != null) return inflight;

    final future = _doResolveStreamUrl(item).then((url) {
      if (url.isNotEmpty) _streamUrlCache[item.id] = _CachedStreamUrl(url);
      return url;
    }).whenComplete(() {
      _inflightResolutions.remove(item.id);
    });
    _inflightResolutions[item.id] = future;
    return future;
  }

  Future<String> _doResolveStreamUrl(MediaItem item) async {
    try {
      String? videoId;

      // 1. Vérifier si on a déjà l'ID YouTube en cache (mémoire ou Hive)
      final cachedId = _videoIdCache[item.id] ?? offlineRepository?.getYoutubeMapping(item.id);
      if (cachedId != null && _youtubeIdRegex.hasMatch(cachedId)) {
        videoId = cachedId;
      } else if (!item.id.startsWith('deezer_') && _youtubeIdRegex.hasMatch(item.id)) {
        videoId = item.id;
      }

      if (videoId != null) {
        final directUrl = await _extractMuxedStreamUrl(videoId);
        if (directUrl.isNotEmpty) {
          _videoIdCache[item.id] = videoId;
          return directUrl;
        }
        _videoIdCache.remove(item.id);
        offlineRepository?.deleteYoutubeMapping(item.id);
      }

      // 2. Recherche directe sur YouTube à partir de l'artiste et du titre
      final cleanTitle = item.title
          .replaceAll(RegExp(r'\s*[\(\[][^\)\]]*(?:feat|ft|officiel|clip|video)[^\)\]]*[\)\]]', caseSensitive: false), '')
          .trim();
      final cleanArtist = (item.artist ?? '')
          .split(RegExp(r',|&|feat\.|ft\.', caseSensitive: false))
          .first
          .trim();

      final query = '$cleanArtist $cleanTitle'.trim();
      final searchQuery = query.isNotEmpty ? query : item.title;

      debugPrint('[playback] Searching YouTube for: "$searchQuery"');
      final searchResults = await _yt.search.search(searchQuery).timeout(const Duration(seconds: 8));

      for (final video in searchResults.take(5)) {
        if (video.isLive) continue;
        final candidateId = video.id.value;
        if (candidateId.isEmpty) continue;

        final streamUrl = await _extractMuxedStreamUrl(candidateId);
        if (streamUrl.isNotEmpty) {
          _videoIdCache[item.id] = candidateId;
          offlineRepository?.saveYoutubeMapping(item.id, candidateId);
          return streamUrl;
        }
      }
    } catch (e) {
      debugPrint('Error in _doResolveStreamUrl for ${item.id}: $e');
    }
    return '';
  }

  String _buildBackendYoutubeStreamUrl(MediaItem item) {
    final cachedId =
        _videoIdCache[item.id] ?? offlineRepository?.getYoutubeMapping(item.id);
    if (cachedId != null && _youtubeIdRegex.hasMatch(cachedId)) {
      return '${ApiConstants.baseUrl}/api/tracks/youtube-stream/?video_id=${Uri.encodeComponent(cachedId)}';
    }
    if (!item.id.startsWith('deezer_') && _youtubeIdRegex.hasMatch(item.id)) {
      return '${ApiConstants.baseUrl}/api/tracks/youtube-stream/?video_id=${Uri.encodeComponent(item.id)}';
    }
    final cleanTitle = item.title
        .replaceAll(
          RegExp(r'\s*[\(\[][^\)\]]*(?:feat|ft|officiel|clip|video)[^\)\]]*[\)\]]',
              caseSensitive: false),
          '',
        )
        .trim();
    final cleanArtist = (item.artist ?? '')
        .split(RegExp(r',|&|feat\.|ft\.', caseSensitive: false))
        .first
        .trim();
    final query = '$cleanArtist $cleanTitle'.trim();
    final searchQuery = query.isNotEmpty ? query : item.title;
    return '${ApiConstants.baseUrl}/api/tracks/youtube-stream/?q=${Uri.encodeComponent(searchQuery)}';
  }

  /// Résolution audio complète (3 à 5 min) pour le navigateur Web (Chrome / Edge) :
  /// 1. Tente d'extraire le flux complet YouTube `itag 18` via `_resolveStreamUrl`.
  /// 2. Sinon, utilise le flux complet YouTube relayé par le backend (`/api/tracks/youtube-stream/`)
  ///    afin de ne jamais jouer les extraits de 30 secondes de Deezer.
  Future<String> _resolveWebStreamUrl(MediaItem item) async {
    final cached = _streamUrlCache[item.id];
    if (cached != null &&
        DateTime.now().difference(cached.resolvedAt) < _streamUrlTtl) {
      return cached.url;
    }

    try {
      final directYtUrl = await _resolveStreamUrl(item);
      if (directYtUrl.isNotEmpty) {
        return directYtUrl;
      }
    } catch (_) {}

    final backendStreamUrl = _buildBackendYoutubeStreamUrl(item);
    _streamUrlCache[item.id] = _CachedStreamUrl(backendStreamUrl);
    return backendStreamUrl;
  }

  Future<String> _extractMuxedStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidSdkless],
        requireWatchPage: false,
      ).timeout(const Duration(seconds: 4));

      if (manifest.muxed.isNotEmpty) {
        final itag18 = manifest.muxed.where((s) => s.tag == 18).firstOrNull;
        if (itag18 != null) {
          return itag18.url.toString();
        }
        try {
          return manifest.muxed.sortByVideoQuality().first.url.toString();
        } catch (_) {
          return manifest.muxed.first.url.toString();
        }
      }

      if (manifest.audioOnly.isNotEmpty) {
        return manifest.audioOnly.withHighestBitrate().url.toString();
      }
    } catch (e) {
      debugPrint('androidSdkless manifest failed for $videoId: $e');
    }

    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 6));

      if (manifest.muxed.isNotEmpty) {
        final itag18 = manifest.muxed.where((s) => s.tag == 18).firstOrNull;
        if (itag18 != null) {
          return itag18.url.toString();
        }
        try {
          return manifest.muxed.sortByVideoQuality().first.url.toString();
        } catch (_) {
          return manifest.muxed.first.url.toString();
        }
      }

      if (manifest.audioOnly.isNotEmpty) {
        return manifest.audioOnly.withHighestBitrate().url.toString();
      }
    } catch (e) {
      debugPrint('Standard manifest failed for $videoId: $e');
    }

    return '';
  }

  @override
  Future<void> play() async {
    if (_isResolving) return;
    if ((_player.processingState == ProcessingState.idle ||
            _player.processingState == ProcessingState.completed) &&
        mediaItem.value != null) {
      await playTrack(mediaItem.value!);
      return;
    }
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (onSkipToNext != null) {
      await onSkipToNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPrevious != null) {
      await onSkipToPrevious!();
    }
  }

  @override
  Future<void> stop() async {
    _playRequestId++;
    _setResolving(false);
    await _player.stop();
    await super.stop();
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
  }

  Future<void> setLoopMode(LoopMode loopMode) async {
    // Le PlayerCubit gère LoopMode.one / LoopMode.all sur toute la file d'attente.
    // On garde ExoPlayer en LoopMode.off pour que ProcessingState.completed soit toujours émis.
    await _player.setLoopMode(LoopMode.off);
  }
}

Future<SonoritizAudioHandler> initAudioHandler({OfflineRepository? offlineRepository}) async {
  final isDesktopOs = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
  if (isDesktopOs) {
    return SonoritizAudioHandler(offlineRepository: offlineRepository);
  }
  try {
    return await AudioService.init(
      builder: () => SonoritizAudioHandler(offlineRepository: offlineRepository),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.sonoritiz.app.channel.audio',
        androidNotificationChannelName: 'Sonoritiz Audio Streaming',
        androidNotificationIcon: 'drawable/ic_stat_logo_transparent',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidResumeOnClick: true,
      ),
    );
  } catch (_) {
    return SonoritizAudioHandler(offlineRepository: offlineRepository);
  }
}
