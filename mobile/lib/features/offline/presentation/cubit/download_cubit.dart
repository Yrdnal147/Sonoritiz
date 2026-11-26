import 'dart:collection';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../player/data/models/track_model.dart';
import '../../data/models/offline_track_model.dart';
import '../../data/repositories/offline_repository.dart';

enum DownloadStatus {
  queued,
  downloading,
  paused,
  failed,
}

class ActiveDownloadTask extends Equatable {
  final TrackModel track;
  final double progress;
  final DownloadStatus status;
  final String? errorMessage;
  final int downloadedBytes;
  final int totalBytes;

  const ActiveDownloadTask({
    required this.track,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.errorMessage,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
  });

  ActiveDownloadTask copyWith({
    TrackModel? track,
    double? progress,
    DownloadStatus? status,
    String? errorMessage,
    int? downloadedBytes,
    int? totalBytes,
  }) {
    return ActiveDownloadTask(
      track: track ?? this.track,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }

  @override
  List<Object?> get props => [track, progress, status, errorMessage, downloadedBytes, totalBytes];
}

abstract class DownloadState extends Equatable {
  const DownloadState();
  @override
  List<Object> get props => [];
}

class DownloadInitial extends DownloadState {}

class DownloadStateData extends DownloadState {
  final Map<String, ActiveDownloadTask> activeTasks;
  final Map<String, double> downloadingProgress;
  final List<String> downloadedIds;
  final List<OfflineTrackModel> offlineTracks;

  const DownloadStateData({
    required this.activeTasks,
    required this.downloadingProgress,
    required this.downloadedIds,
    required this.offlineTracks,
  });

  @override
  List<Object> get props => [activeTasks, downloadingProgress, downloadedIds, offlineTracks];

  DownloadStateData copyWith({
    Map<String, ActiveDownloadTask>? activeTasks,
    Map<String, double>? downloadingProgress,
    List<String>? downloadedIds,
    List<OfflineTrackModel>? offlineTracks,
  }) {
    return DownloadStateData(
      activeTasks: activeTasks ?? this.activeTasks,
      downloadingProgress: downloadingProgress ?? this.downloadingProgress,
      downloadedIds: downloadedIds ?? this.downloadedIds,
      offlineTracks: offlineTracks ?? this.offlineTracks,
    );
  }
}

class DownloadCubit extends Cubit<DownloadState> {
  final OfflineRepository repository;
  static const int _maxConcurrent = 2;

  final Queue<TrackModel> _queue = Queue<TrackModel>();
  final Set<String> _runningTrackIds = <String>{};

  DownloadCubit({required this.repository}) : super(DownloadInitial());

  DownloadStateData get _data => state is DownloadStateData
      ? state as DownloadStateData
      : const DownloadStateData(
          activeTasks: {},
          downloadingProgress: {},
          downloadedIds: [],
          offlineTracks: [],
        );

  Future<void> reloadForCurrentUser() async {
    await repository.switchUserBox();
    loadDownloads();
  }

  Future<void> resetSessionState() async {
    _queue.clear();
    _runningTrackIds.clear();
    await repository.switchUserBox();
    emit(DownloadInitial());
  }

  void loadDownloads() {
    final offlineTracks = repository.getAllDownloads();
    final downloadedIds = offlineTracks.map<String>((e) => e.track.id).toList();
    emit(DownloadStateData(
      activeTasks: _data.activeTasks,
      downloadingProgress: _data.downloadingProgress,
      downloadedIds: downloadedIds,
      offlineTracks: offlineTracks,
    ));
  }

  Future<void> downloadTrack(TrackModel track) async {
    final current = _data;
    if (current.downloadedIds.contains(track.id)) {
      return;
    }

    final existingTask = current.activeTasks[track.id];
    if (existingTask != null) {
      if (existingTask.status == DownloadStatus.paused) {
        resumeDownload(track.id);
        return;
      }
      if (existingTask.status == DownloadStatus.failed) {
        retryDownload(track.id);
        return;
      }
      return;
    }

    final newTask = ActiveDownloadTask(
      track: track,
      progress: 0.0,
      status: DownloadStatus.queued,
    );

    final updatedTasks = Map<String, ActiveDownloadTask>.from(current.activeTasks)..[track.id] = newTask;
    final updatedProgress = Map<String, double>.from(current.downloadingProgress)..[track.id] = 0.0;

    emit(current.copyWith(
      activeTasks: updatedTasks,
      downloadingProgress: updatedProgress,
    ));

    _queue.add(track);
    _pump();
  }

  void pauseDownload(String trackId) {
    repository.pauseDownload(trackId);
    _queue.removeWhere((t) => t.id == trackId);
    final current = _data;
    final task = current.activeTasks[trackId];
    if (task != null) {
      final updatedTasks = Map<String, ActiveDownloadTask>.from(current.activeTasks)
        ..[trackId] = task.copyWith(status: DownloadStatus.paused);
      emit(current.copyWith(activeTasks: updatedTasks));
    }
  }

  void resumeDownload(String trackId) {
    final current = _data;
    final task = current.activeTasks[trackId];
    if (task != null && task.status == DownloadStatus.paused) {
      final updatedTasks = Map<String, ActiveDownloadTask>.from(current.activeTasks)
        ..[trackId] = task.copyWith(status: DownloadStatus.queued);
      emit(current.copyWith(activeTasks: updatedTasks));

      if (!_queue.any((t) => t.id == trackId) && !_runningTrackIds.contains(trackId)) {
        _queue.add(task.track);
      }
      _pump();
    }
  }

  void cancelDownload(String trackId) {
    repository.cancelDownload(trackId);
    _queue.removeWhere((t) => t.id == trackId);
    _runningTrackIds.remove(trackId);

    final current = _data;
    final updatedTasks = Map<String, ActiveDownloadTask>.from(current.activeTasks)..remove(trackId);
    final updatedProgress = Map<String, double>.from(current.downloadingProgress)..remove(trackId);

    emit(current.copyWith(
      activeTasks: updatedTasks,
      downloadingProgress: updatedProgress,
    ));

    _pump();
  }

  void retryDownload(String trackId) {
    final current = _data;
    final task = current.activeTasks[trackId];
    if (task != null) {
      final updatedTasks = Map<String, ActiveDownloadTask>.from(current.activeTasks)
        ..[trackId] = task.copyWith(status: DownloadStatus.queued, errorMessage: null, progress: 0.0);
      final updatedProgress = Map<String, double>.from(current.downloadingProgress)
        ..[trackId] = 0.0;
      emit(current.copyWith(
        activeTasks: updatedTasks,
        downloadingProgress: updatedProgress,
      ));

      if (!_queue.any((t) => t.id == trackId) && !_runningTrackIds.contains(trackId)) {
        _queue.add(task.track);
      }
      _pump();
    }
  }

  void _pump() {
    while (!isClosed && _runningTrackIds.length < _maxConcurrent && _queue.isNotEmpty) {
      final track = _queue.removeFirst();
      _runningTrackIds.add(track.id);

      final current = _data;
      final existingTask = current.activeTasks[track.id] ?? ActiveDownloadTask(track: track);
      final updatedTasks = Map<String, ActiveDownloadTask>.from(current.activeTasks)
        ..[track.id] = existingTask.copyWith(status: DownloadStatus.downloading);
      emit(current.copyWith(activeTasks: updatedTasks));

      _runDownload(track).whenComplete(() {
        _runningTrackIds.remove(track.id);
        _pump();
      });
    }
  }

  Future<void> _runDownload(TrackModel track) async {
    double lastEmitted = 0.0;

    try {
      await repository.downloadTrack(
        track,
        onProgress: (progress, downloadedBytes, totalBytes) {
          if (isClosed) return;
          if (progress < 1.0 && progress - lastEmitted < 0.02) return;
          lastEmitted = progress;

          final s = _data;
          final task = s.activeTasks[track.id];
          if (task != null && task.status == DownloadStatus.downloading) {
            final updatedTasks = Map<String, ActiveDownloadTask>.from(s.activeTasks)
              ..[track.id] = task.copyWith(
                progress: progress,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
              );
            final updatedProgress = Map<String, double>.from(s.downloadingProgress)
              ..[track.id] = progress;

            emit(s.copyWith(
              activeTasks: updatedTasks,
              downloadingProgress: updatedProgress,
            ));
          }
        },
      );

      if (isClosed) return;
      final s = _data;
      final updatedTasks = Map<String, ActiveDownloadTask>.from(s.activeTasks)..remove(track.id);
      final updatedProgress = Map<String, double>.from(s.downloadingProgress)..remove(track.id);
      final offlineTracks = repository.getAllDownloads();
      final downloadedIds = offlineTracks.map<String>((e) => e.track.id).toList();

      emit(s.copyWith(
        activeTasks: updatedTasks,
        downloadingProgress: updatedProgress,
        downloadedIds: downloadedIds,
        offlineTracks: offlineTracks,
      ));
    } on DownloadPausedException {
      if (isClosed) return;
      final s = _data;
      final task = s.activeTasks[track.id];
      if (task != null) {
        final updatedTasks = Map<String, ActiveDownloadTask>.from(s.activeTasks)
          ..[track.id] = task.copyWith(status: DownloadStatus.paused);
        emit(s.copyWith(activeTasks: updatedTasks));
      }
    } on DownloadCancelledException {
      if (isClosed) return;
      final s = _data;
      final updatedTasks = Map<String, ActiveDownloadTask>.from(s.activeTasks)..remove(track.id);
      final updatedProgress = Map<String, double>.from(s.downloadingProgress)..remove(track.id);
      emit(s.copyWith(
        activeTasks: updatedTasks,
        downloadingProgress: updatedProgress,
      ));
    } catch (e, stack) {
      debugPrint('DownloadCubit error for ${track.title} (${track.id}): $e\n$stack');
      if (isClosed) return;
      final s = _data;
      final task = s.activeTasks[track.id];
      if (task != null) {
        final updatedTasks = Map<String, ActiveDownloadTask>.from(s.activeTasks)
          ..[track.id] = task.copyWith(
            status: DownloadStatus.failed,
            errorMessage: e.toString(),
          );
        emit(s.copyWith(activeTasks: updatedTasks));
      }
    }
  }

  Future<void> downloadAlbum({
    required String albumId,
    required String title,
    required String artistName,
    required String coverUrl,
    required List<TrackModel> tracks,
  }) async {
    if (tracks.isEmpty) return;
    await StorageService().registerDownloadedAlbum(
      id: albumId,
      title: title,
      artistName: artistName,
      coverUrl: coverUrl,
      trackIds: tracks.map((t) => t.id).toList(),
    );
    for (final track in tracks) {
      final enriched = track.albumName.trim().isEmpty
          ? track.copyWith(albumName: title)
          : track;
      await downloadTrack(enriched);
    }
  }

  Future<void> removeAlbumDownload({
    required String albumId,
    required String title,
    required String artistName,
    required List<String> trackIds,
  }) async {
    await StorageService().unregisterDownloadedAlbum(
      id: albumId,
      title: title,
      artistName: artistName,
    );
    for (final tid in trackIds) {
      cancelDownload(tid);
      await repository.deleteDownload(tid);
    }
    loadDownloads();
  }

  Future<void> removeDownload(String trackId) async {
    cancelDownload(trackId);
    await repository.deleteDownload(trackId);
    loadDownloads();
  }
}
