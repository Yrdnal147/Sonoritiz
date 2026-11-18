import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/storage/storage_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/offline_track_model.dart';
import '../../../player/data/models/track_model.dart';

class DownloadPausedException implements Exception {
  final String message;
  DownloadPausedException([this.message = 'Download paused']);
  @override
  String toString() => message;
}

class DownloadCancelledException implements Exception {
  final String message;
  DownloadCancelledException([this.message = 'Download cancelled']);
  @override
  String toString() => message;
}

class _ActiveDownloadJob {
  bool isPaused = false;
  bool isCancelled = false;
  CancelToken? dioCancelToken;
}

class OfflineRepository {
  final Dio _dio;
  final YoutubeExplode _yt;
  static const String _legacyBoxName = 'offline_tracks';
  static const String _ytMappingBoxName = 'youtube_mappings';
  late Box<String> _box;
  late Box<String> _ytBox;
  String _openedScope = '';

  String get _currentBoxName {
    final slug = StorageService().safeAccountSlug;
    return '${_legacyBoxName}_$slug';
  }

  final Map<String, _ActiveDownloadJob> _activeJobs = {};

  OfflineRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 45),
            )),
        _yt = YoutubeExplode();

  Future<void> init() async {
    _openedScope = StorageService().safeAccountSlug;
    _box = await Hive.openBox<String>(_currentBoxName);
    _ytBox = await Hive.openBox<String>(_ytMappingBoxName);
    await _migrateLegacyOfflineBoxIfNeeded();
  }

  Future<void> switchUserBox() async {
    final targetSlug = StorageService().safeAccountSlug;
    if (_openedScope == targetSlug && Hive.isBoxOpen(_currentBoxName)) {
      _box = Hive.box<String>(_currentBoxName);
      await _migrateLegacyOfflineBoxIfNeeded();
      return;
    }
    try {
      if (_box.isOpen) {
        await _box.close();
      }
    } catch (_) {}
    _openedScope = targetSlug;
    _box = await Hive.openBox<String>(_currentBoxName);
    await _migrateLegacyOfflineBoxIfNeeded();
  }

  Future<void> _migrateLegacyOfflineBoxIfNeeded() async {
    try {
      final storage = StorageService();
      if (!storage.isAuthenticated) return;
      final metaBox = await Hive.openBox<String>('sonoritiz_offline_meta');
      if (metaBox.get('migrated_v1') == 'true') return;

      final legacyBox = await Hive.openBox<String>(_legacyBoxName);
      if (legacyBox.isNotEmpty && _box.isEmpty) {
        for (final key in legacyBox.keys) {
          final val = legacyBox.get(key);
          if (val != null) {
            await _box.put(key, val);
          }
        }
        await legacyBox.clear();
      }
      await metaBox.put('migrated_v1', 'true');
    } catch (_) {}
  }

  void saveYoutubeMapping(String deezerId, String youtubeId) {
    _ytBox.put(deezerId, youtubeId);
  }

  String? getYoutubeMapping(String deezerId) {
    return _ytBox.get(deezerId);
  }

  void deleteYoutubeMapping(String deezerId) {
    _ytBox.delete(deezerId);
  }

  bool isDownloaded(String trackId) {
    if (kIsWeb) return false;
    if (!_box.containsKey(trackId)) return false;
    final track = getOfflineTrack(trackId);
    if (track == null || track.localAudioPath.isEmpty || !File(track.localAudioPath).existsSync()) {
      _box.delete(trackId);
      return false;
    }
    return true;
  }

  OfflineTrackModel? getOfflineTrack(String trackId) {
    if (kIsWeb) return null;
    final data = _box.get(trackId);
    if (data != null) {
      try {
        final track = OfflineTrackModel.fromJson(jsonDecode(data));
        if (track.localAudioPath.isNotEmpty && File(track.localAudioPath).existsSync()) {
          return track;
        }
      } catch (e) {
        debugPrint("Error parsing offline track: $e");
      }
    }
    return null;
  }

  List<OfflineTrackModel> getAllDownloads() {
    if (kIsWeb) return const [];
    return _box.values
        .map((data) {
          try {
            final track = OfflineTrackModel.fromJson(jsonDecode(data));
            if (track.localAudioPath.isNotEmpty && File(track.localAudioPath).existsSync()) {
              return track;
            }
            return null;
          } catch (_) {
            return null;
          }
        })
        .whereType<OfflineTrackModel>()
        .toList();
  }

  void pauseDownload(String trackId) {
    final job = _activeJobs[trackId];
    if (job != null) {
      job.isPaused = true;
      job.dioCancelToken?.cancel('PAUSED');
    }
  }

  void cancelDownload(String trackId) {
    final job = _activeJobs[trackId];
    if (job != null) {
      job.isCancelled = true;
      job.dioCancelToken?.cancel('CANCELLED');
    }
  }

  Future<String?> _getPlayableStreamUrl(String videoId) async {
    // 1. Clients mobiles sans SDK (androidSdkless) pour éviter les blocs PO-Token 403
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidSdkless],
        requireWatchPage: false,
      ).timeout(const Duration(seconds: 10));

      // Priorité 1 : itag 18 (MP4 progressif, stéréo AAC 44.1kHz).
      // Ne nécessite aucun PO-Token et se télécharge via Dio sans blocage 403.
      final itag18 = manifest.muxed.where((s) => s.tag == 18).firstOrNull;
      if (itag18 != null) {
        return itag18.url.toString();
      }

      // Priorité 2 : Autre flux progressif muxé
      if (manifest.muxed.isNotEmpty) {
        return manifest.muxed.first.url.toString();
      }

      // Priorité 3 : Flux audio seul
      if (manifest.audioOnly.isNotEmpty) {
        return manifest.audioOnly.withHighestBitrate().url.toString();
      }
    } catch (e) {
      debugPrint("Light clients manifest failed for $videoId: $e");
    }

    // 2. Repli Piped API public si YouTube direct bloque
    final pipedInstances = [
      'https://pipedapi.tokhmi.xyz/streams/$videoId',
      'https://pipedapi.kavin.rocks/streams/$videoId',
      'https://piped.video/api/v1/streams/$videoId',
    ];
    for (final endpoint in pipedInstances) {
      try {
        final res = await _dio.get<dynamic>(
          endpoint,
          options: Options(responseType: ResponseType.plain),
        ).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200 && res.data != null) {
          final dynamic raw = res.data is String ? jsonDecode(res.data as String) : res.data;
          if (raw is Map) {
            final audioStreams = raw['audioStreams'];
            if (audioStreams is List && audioStreams.isNotEmpty) {
              final bestStream = audioStreams.first;
              final url = bestStream['url']?.toString() ?? '';
              if (url.isNotEmpty) {
                return url;
              }
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  Future<String?> _resolveAudioStreamUrl(TrackModel track) async {
    // ⚠️ Rejeter catégoriquement les extraits Deezer (30 secondes)
    if (track.audioUrl.isNotEmpty && !track.audioUrl.startsWith('file://')) {
      final isPreview = track.audioUrl.contains('dzcdn.net') || track.audioUrl.contains('preview');
      if (!isPreview) {
        return track.audioUrl;
      }
    }

    // 1. Essayer le cache de mapping
    final cached = getYoutubeMapping(track.id);
    if (cached != null && cached.isNotEmpty) {
      final url = await _getPlayableStreamUrl(cached);
      if (url != null && url.isNotEmpty) {
        return url;
      } else {
        deleteYoutubeMapping(track.id);
      }
    }

    // 2. Si track.id est un ID YouTube direct (11 caractères sans espaces ni préfixe)
    final isDirectYoutubeId = RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(track.id);
    if (isDirectYoutubeId) {
      final url = await _getPlayableStreamUrl(track.id);
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }

    // 3. Recherche sur YouTube pour tout morceau (Deezer, catalogue ou autre)
    final cleanTitle = track.title
        .replaceAll(RegExp(r'\s*[\(\[][^\)\]]*(?:feat|ft|remix|version|officiel|clip|audio)[^\)\]]*[\)\]]', caseSensitive: false), '')
        .trim();
    final cleanArtist = track.artistName
        .split(RegExp(r',|&|feat\.|ft\.', caseSensitive: false))
        .first
        .trim();

    final queries = [
      "$cleanArtist $cleanTitle audio".trim(),
      "$cleanArtist $cleanTitle".trim(),
      "${track.artistName} ${track.title}".trim(),
    ];

    for (final q in queries) {
      if (q.isEmpty) continue;
      try {
        final searchResults = await _yt.search.search(q).timeout(const Duration(seconds: 10));
        if (searchResults.isNotEmpty) {
          final videoId = searchResults.first.id.value;
          final url = await _getPlayableStreamUrl(videoId);
          if (url != null && url.isNotEmpty) {
            saveYoutubeMapping(track.id, videoId);
            return url;
          }
        }
      } catch (e) {
        debugPrint("YouTube search failed for '$q': $e");
      }
    }

    return null;
  }

  Future<void> downloadTrack(
    TrackModel track, {
    required void Function(double progress, int downloadedBytes, int totalBytes) onProgress,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final slug = StorageService().safeAccountSlug;
    final offlineDir = Directory('${appDir.path}/downloads/$slug');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }

    final safeId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    final job = _ActiveDownloadJob();
    _activeJobs[track.id] = job;

    IOSink? sink;
    File? tempFile;

    try {
      if (job.isCancelled) throw DownloadCancelledException();
      if (job.isPaused) throw DownloadPausedException();

      final streamUrl = await _resolveAudioStreamUrl(track);
      if (streamUrl == null || streamUrl.isEmpty || streamUrl.contains('dzcdn.net') || streamUrl.contains('preview')) {
        throw Exception("Impossible de résoudre le flux complet pour ce titre.");
      }

      // Détecter l'extension réelle du conteneur audio
      String ext = 'mp4';
      if (streamUrl.contains('audio/webm') || streamUrl.contains('audio%2Fwebm') || streamUrl.contains('opus')) {
        ext = 'webm';
      } else if (streamUrl.contains('.mp3') || streamUrl.contains('audio/mpeg')) {
        ext = 'mp3';
      } else if (streamUrl.contains('.m4a') || streamUrl.contains('audio/mp4')) {
        ext = 'm4a';
      }
      final localAudioPath = '${offlineDir.path}/track_$safeId.$ext';
      final tempAudioPath = '${offlineDir.path}/track_$safeId.$ext.part';

      tempFile = File(tempAudioPath);
      int existingBytes = 0;
      if (await tempFile.exists()) {
        existingBytes = await tempFile.length();
      }

      job.dioCancelToken = CancelToken();

      final Map<String, dynamic> headers = {};
      if (existingBytes > 0) {
        headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await _dio.get<ResponseBody>(
        streamUrl,
        cancelToken: job.dioCancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          validateStatus: (status) => status != null && (status >= 200 && status < 400),
        ),
      );

      final statusCode = response.statusCode ?? 200;
      final isAppend = (statusCode == 206 && existingBytes > 0);
      int downloadedBytes = isAppend ? existingBytes : 0;

      final contentLengthHeader = response.headers.value(HttpHeaders.contentLengthHeader);
      final responseContentLength = int.tryParse(contentLengthHeader ?? '') ?? 0;
      final int totalBytes = isAppend
          ? (existingBytes + responseContentLength)
          : responseContentLength;

      sink = tempFile.openWrite(mode: isAppend ? FileMode.append : FileMode.write);
      sink.done.catchError((e) {
        debugPrint("Sink done error for ${track.id}: $e");
      });

      await for (final chunk in response.data!.stream) {
        if (job.isCancelled) {
          throw DownloadCancelledException();
        }
        if (job.isPaused) {
          throw DownloadPausedException();
        }

        sink.add(chunk);
        downloadedBytes += chunk.length;

        final double p = totalBytes > 0
            ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0;
        onProgress(p, downloadedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (job.isCancelled) throw DownloadCancelledException();
      if (job.isPaused) throw DownloadPausedException();

      // Renommer le fichier partiel en fichier audio définitif
      final finalAudioFile = File(localAudioPath);
      if (await finalAudioFile.exists()) {
        await finalAudioFile.delete();
      }
      await tempFile.rename(localAudioPath);

      // Télécharger la pochette si disponible
      String localCoverPath = '';
      if (track.coverUrl.isNotEmpty) {
        try {
          final coverExt = track.coverUrl.split('.').last.split('?').first;
          final validExt = ['jpg', 'png', 'jpeg'].contains(coverExt.toLowerCase()) ? coverExt : 'jpg';
          localCoverPath = '${offlineDir.path}/cover_$safeId.$validExt';
          await _dio.download(
            track.coverUrl,
            localCoverPath,
            cancelToken: job.dioCancelToken,
          );
        } catch (_) {
          localCoverPath = '';
        }
      }

      final offlineTrack = OfflineTrackModel(
        track: track,
        localAudioPath: localAudioPath,
        localCoverPath: localCoverPath,
        downloadedAt: DateTime.now(),
      );

      await _box.put(track.id, jsonEncode(offlineTrack.toJson()));
    } on DioException catch (dioErr) {
      if (job.isCancelled || (dioErr.type == DioExceptionType.cancel && dioErr.error == 'CANCELLED')) {
        throw DownloadCancelledException();
      }
      if (job.isPaused || (dioErr.type == DioExceptionType.cancel && dioErr.error == 'PAUSED')) {
        throw DownloadPausedException();
      }
      rethrow;
    } finally {
      _activeJobs.remove(track.id);
      try {
        await sink?.flush();
        await sink?.close();
      } catch (_) {}

      if (job.isCancelled) {
        try {
          if (tempFile != null && await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  Future<void> deleteDownload(String trackId) async {
    cancelDownload(trackId);
    final track = getOfflineTrack(trackId);
    if (track != null) {
      try {
        final audioFile = File(track.localAudioPath);
        if (await audioFile.exists()) await audioFile.delete();

        if (track.localCoverPath.isNotEmpty) {
          final coverFile = File(track.localCoverPath);
          if (await coverFile.exists()) await coverFile.delete();
        }
      } catch (_) {}
      await _box.delete(trackId);
    }
  }
}
