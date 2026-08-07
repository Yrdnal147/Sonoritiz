import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/storage/storage_service.dart';

enum ViewMode { list, gridSmall, gridMedium, gridLarge }
enum SortMode { alpha, recent }

class LibraryUiState extends Equatable {
  final ViewMode viewMode;
  final SortMode sortMode;

  const LibraryUiState({required this.viewMode, required this.sortMode});

  LibraryUiState copyWith({ViewMode? viewMode, SortMode? sortMode}) {
    return LibraryUiState(
      viewMode: viewMode ?? this.viewMode,
      sortMode: sortMode ?? this.sortMode,
    );
  }

  @override
  List<Object> get props => [viewMode, sortMode];
}

class LibraryUiCubit extends Cubit<LibraryUiState> {
  final StorageService storageService;

  LibraryUiCubit({required this.storageService})
      : super(LibraryUiState(
          viewMode: _parseViewMode(storageService.getViewMode()),
          sortMode: _parseSortMode(storageService.getSortMode()),
        ));

  void setViewMode(ViewMode mode) {
    storageService.saveViewMode(_viewModeToString(mode));
    emit(state.copyWith(viewMode: mode));
  }

  void setSortMode(SortMode mode) {
    storageService.saveSortMode(_sortModeToString(mode));
    emit(state.copyWith(sortMode: mode));
  }

  void toggleSortMode() {
    final newMode = state.sortMode == SortMode.alpha ? SortMode.recent : SortMode.alpha;
    setSortMode(newMode);
  }

  static ViewMode _parseViewMode(String mode) {
    switch (mode) {
      case 'gridSmall': return ViewMode.gridSmall;
      case 'gridMedium': return ViewMode.gridMedium;
      case 'gridLarge': return ViewMode.gridLarge;
      case 'list':
      default:
        return ViewMode.list;
    }
  }

  static String _viewModeToString(ViewMode mode) {
    switch (mode) {
      case ViewMode.gridSmall: return 'gridSmall';
      case ViewMode.gridMedium: return 'gridMedium';
      case ViewMode.gridLarge: return 'gridLarge';
      case ViewMode.list: return 'list';
    }
  }

  static SortMode _parseSortMode(String mode) {
    switch (mode) {
      case 'recent': return SortMode.recent;
      case 'alpha':
      default:
        return SortMode.alpha;
    }
  }

  static String _sortModeToString(SortMode mode) {
    switch (mode) {
      case SortMode.recent: return 'recent';
      case SortMode.alpha: return 'alpha';
    }
  }
}
