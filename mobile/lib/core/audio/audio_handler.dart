import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'youtube_audio_source.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../features/offline/data/repositories/offline_repository.dart';

class SonoritizAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();
  final OfflineRepository? offlineRepository;

  AudioPlayer get player => _player;

  SonoritizAudioHandler({this.offlineRepository}) {
    _initPlayerListeners();
  }

  void _initPlayerListeners() {
    // Listen to playback state changes and map to AudioService PlaybackState
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 3],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ),
      );
    }, onError: (Object e, StackTrace stackTrace) {
      print('====== JUST AUDIO ASYNC ERROR ======');
      print('Error: \$e');
      print('====================================');
    });

    // Listen to current item duration
    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });
  }

  Future<void> playTrack(MediaItem item) async {
    mediaItem.add(item);
    String audioUrl = item.extras?['audio_url'] ?? '';

    try {
      // 1. Check if track is available offline
      if (offlineRepository != null) {
        final offlineTrack = offlineRepository!.getOfflineTrack(item.id);
        if (offlineTrack != null && await File(offlineTrack.localAudioPath).exists()) {
          print('Playing OFFLINE file: \${offlineTrack.localAudioPath}');
          await _player.setAudioSource(AudioSource.uri(Uri.file(offlineTrack.localAudioPath)));
          await _player.play();
          return;
        }
      }

      print('Setting URL...');
      
      // Si on a un ID YouTube, on force l'utilisation du flux complet (Vidéo + Audio)
      // car YouTube bloque souvent (403) les flux purement audio pour les bots.
      if (audioUrl.isEmpty && item.id.isNotEmpty) {
        final manifest = await _yt.videos.streamsClient.getManifest(item.id);
        
        // On récupère le flux MP4 standard (muxed) avec la qualité la plus BASSE
        // car on n'a besoin que du son ! Ça va régler le problème de "ça cale" (buffering).
        final streamInfo = manifest.muxed.sortByVideoQuality().last;
        audioUrl = streamInfo.url.toString();
      }

      if (audioUrl.isEmpty) {
        audioUrl = item.id;
      }
      
      if (audioUrl.startsWith('file://')) {
        print('Playing LOCAL file: $audioUrl');
        await _player.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));
      } else {
        print('Playing URL (Muxed) avec Caching agressif...');
        await _player.setAudioSource(LockCachingAudioSource(Uri.parse(audioUrl)));
      }
      
      await _player.play();
    } catch (e, stack) {
      print("Audio playback error: \$e");
      print(stack);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
  }

  Future<void> setLoopMode(LoopMode loopMode) async {
    await _player.setLoopMode(loopMode);
  }
}

Future<SonoritizAudioHandler> initAudioHandler({OfflineRepository? offlineRepository}) async {
  return await AudioService.init(
    builder: () => SonoritizAudioHandler(offlineRepository: offlineRepository),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.sonoritiz.app.channel.audio',
      androidNotificationChannelName: 'Sonoritiz Audio Streaming',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
