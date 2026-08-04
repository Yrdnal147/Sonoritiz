import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/offline_track_model.dart';
import '../../../player/data/models/track_model.dart';

class OfflineRepository {
  final Dio _dio;
  final YoutubeExplode _yt;
  static const String _boxName = 'offline_tracks';
  late Box<String> _box;

  OfflineRepository({Dio? dio}) 
      : _dio = dio ?? Dio(),
        _yt = YoutubeExplode();

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool isDownloaded(String trackId) {
    return _box.containsKey(trackId);
  }

  OfflineTrackModel? getOfflineTrack(String trackId) {
    final data = _box.get(trackId);
    if (data != null) {
      return OfflineTrackModel.fromJson(jsonDecode(data));
    }
    return null;
  }

  List<OfflineTrackModel> getAllDownloads() {
    return _box.values.map((data) => OfflineTrackModel.fromJson(jsonDecode(data))).toList();
  }

  Future<void> downloadTrack(TrackModel track, Function(double) onProgress) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${appDir.path}/downloads');
      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
      }

      final audioFileName = 'track_${track.id}.mp4';
      final localAudioPath = '${offlineDir.path}/$audioFileName';
      
      String audioUrl = track.audioUrl;
      
      if (audioUrl.isEmpty && track.id.isNotEmpty) {
        final manifest = await _yt.videos.streamsClient.getManifest(track.id);
        final streamInfo = manifest.muxed.sortByVideoQuality().last;
        audioUrl = streamInfo.url.toString();
      }

      if (audioUrl.isEmpty) {
        throw Exception("Impossible de trouver un lien de téléchargement.");
      }

      // Download audio
      await _dio.download(
        audioUrl,
        localAudioPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // Download cover if exists
      String localCoverPath = '';
      if (track.coverUrl.isNotEmpty) {
        final coverExt = track.coverUrl.split('.').last.split('?').first;
        final validExt = ['jpg', 'png', 'jpeg'].contains(coverExt.toLowerCase()) ? coverExt : 'jpg';
        final coverFileName = 'cover_${track.id}.$validExt';
        localCoverPath = '${offlineDir.path}/$coverFileName';
        
        try {
          await _dio.download(track.coverUrl, localCoverPath);
        } catch (e) {
          localCoverPath = ''; // fallback
        }
      }

      final offlineTrack = OfflineTrackModel(
        track: track,
        localAudioPath: localAudioPath,
        localCoverPath: localCoverPath,
        downloadedAt: DateTime.now(),
      );

      await _box.put(track.id, jsonEncode(offlineTrack.toJson()));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteDownload(String trackId) async {
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
