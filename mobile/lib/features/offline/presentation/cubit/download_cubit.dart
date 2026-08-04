import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../player/data/models/track_model.dart';
import '../../data/repositories/offline_repository.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/offline_track_model.dart';

abstract class DownloadState extends Equatable {
  const DownloadState();
  @override
  List<Object> get props => [];
}

class DownloadInitial extends DownloadState {}

class DownloadStateData extends DownloadState {
  final Map<String, double> downloadingProgress; // id -> progress
  final List<String> downloadedIds;
  final List<OfflineTrackModel> offlineTracks;

  const DownloadStateData({
    required this.downloadingProgress,
    required this.downloadedIds,
    required this.offlineTracks,
  });

  @override
  List<Object> get props => [downloadingProgress, downloadedIds, offlineTracks];

  DownloadStateData copyWith({
    Map<String, double>? downloadingProgress,
    List<String>? downloadedIds,
    List<OfflineTrackModel>? offlineTracks,
  }) {
    return DownloadStateData(
      downloadingProgress: downloadingProgress ?? this.downloadingProgress,
      downloadedIds: downloadedIds ?? this.downloadedIds,
      offlineTracks: offlineTracks ?? this.offlineTracks,
    );
  }
}

class DownloadCubit extends Cubit<DownloadState> {
  final OfflineRepository repository;

  DownloadCubit({required this.repository}) : super(DownloadInitial());

  void loadDownloads() {
    final offlineTracks = repository.getAllDownloads();
    final downloadedIds = offlineTracks.map<String>((e) => e.track.id).toList();
    emit(DownloadStateData(
      downloadingProgress: {},
      downloadedIds: downloadedIds,
      offlineTracks: offlineTracks,
    ));
  }

  Future<void> downloadTrack(TrackModel track) async {
    final currentState = state is DownloadStateData 
        ? state as DownloadStateData 
        : const DownloadStateData(downloadingProgress: {}, downloadedIds: [], offlineTracks: []);

    if (currentState.downloadedIds.contains(track.id) || currentState.downloadingProgress.containsKey(track.id)) {
      return; // Already downloaded or downloading
    }

    final newProgress = Map<String, double>.from(currentState.downloadingProgress);
    newProgress[track.id] = 0.0;
    emit(currentState.copyWith(downloadingProgress: newProgress));

    try {
      await repository.downloadTrack(track, (progress) {
        if (isClosed) return;
        final s = state;
        if (s is DownloadStateData) {
          final p = Map<String, double>.from(s.downloadingProgress);
          p[track.id] = progress;
          emit(s.copyWith(downloadingProgress: p));
        }
      });

      // Done
      if (isClosed) return;
      final finalState = state as DownloadStateData;
      final finalProgress = Map<String, double>.from(finalState.downloadingProgress)..remove(track.id);
      
      final offlineTracks = repository.getAllDownloads();
      final downloadedIds = offlineTracks.map<String>((e) => e.track.id).toList();
      
      emit(finalState.copyWith(
        downloadingProgress: finalProgress,
        downloadedIds: downloadedIds,
        offlineTracks: offlineTracks,
      ));
    } catch (e) {
      if (isClosed) return;
      final finalState = state as DownloadStateData;
      final finalProgress = Map<String, double>.from(finalState.downloadingProgress)..remove(track.id);
      emit(finalState.copyWith(downloadingProgress: finalProgress));
    }
  }

  Future<void> removeDownload(String trackId) async {
    await repository.deleteDownload(trackId);
    loadDownloads();
  }
}
