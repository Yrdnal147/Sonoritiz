import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/storage/storage_service.dart';

enum ViewMode { list, gridSmall, gridMedium, gridLarge }
enum SortMode { alpha, recent }

class LibraryUiState extends Equatable {
  final Map<String, ViewMode> viewModes;
  final Map<String, SortMode> sortModes;
  final String activeTabId; // To know which settings to show in AppBar

  const LibraryUiState({
    required this.viewModes,
    required this.sortModes,
    this.activeTabId = 'favorites',
  });

  LibraryUiState copyWith({
    Map<String, ViewMode>? viewModes,
    Map<String, SortMode>? sortModes,
    String? activeTabId,
  }) {
    return LibraryUiState(
      viewModes: viewModes ?? this.viewModes,
      sortModes: sortModes ?? this.sortModes,
      activeTabId: activeTabId ?? this.activeTabId,
    );
  }

  ViewMode get currentViewMode => viewModes[activeTabId] ?? ViewMode.list;
  SortMode get currentSortMode => sortModes[activeTabId] ?? SortMode.alpha;

  ViewMode getViewModeFor(String tabId) => viewModes[tabId] ?? ViewMode.list;
  SortMode getSortModeFor(String tabId) => sortModes[tabId] ?? SortMode.alpha;

  @override
  List<Object> get props => [viewModes, sortModes, activeTabId];
}

class LibraryUiCubit extends Cubit<LibraryUiState> {
  final StorageService storageService;
  static const List<String> tabIds = ['favorites', 'playlists', 'history', 'downloads', 'local'];

  LibraryUiCubit({required this.storageService}) : super(_initialState(storageService));

  static LibraryUiState _initialState(StorageService storageService) {
    Map<String, ViewMode> initialViewModes = {};
    Map<String, SortMode> initialSortModes = {};

    for (var tabId in tabIds) {
      initialViewModes[tabId] = _parseViewMode(storageService.getViewMode(tabId));
      initialSortModes[tabId] = _parseSortMode(storageService.getSortMode(tabId));
    }

    return LibraryUiState(
      viewModes: initialViewModes,
      sortModes: initialSortModes,
      activeTabId: 'favorites',
    );
  }

  void setActiveTab(int index) {
    if (index >= 0 && index < tabIds.length) {
      emit(state.copyWith(activeTabId: tabIds[index]));
    }
  }

  void setViewMode(ViewMode mode) {
    final tabId = state.activeTabId;
    storageService.saveViewMode(tabId, _viewModeToString(mode));
    
    final newViewModes = Map<String, ViewMode>.from(state.viewModes);
    newViewModes[tabId] = mode;
    
    emit(state.copyWith(viewModes: newViewModes));
  }

  void setSortMode(SortMode mode) {
    final tabId = state.activeTabId;
    storageService.saveSortMode(tabId, _sortModeToString(mode));
    
    final newSortModes = Map<String, SortMode>.from(state.sortModes);
    newSortModes[tabId] = mode;
    
    emit(state.copyWith(sortModes: newSortModes));
  }

  void toggleSortMode() {
    final currentMode = state.currentSortMode;
    final newMode = currentMode == SortMode.alpha ? SortMode.recent : SortMode.alpha;
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
