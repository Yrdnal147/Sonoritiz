import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../home/data/repositories/catalog_repository.dart' show CatalogRepository;
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final CatalogRepository repository;
  final StorageService storageService;
  Timer? _debounce;

  SearchCubit({required this.repository, required this.storageService})
      : super(SearchInitial(recentSearches: storageService.getSearchHistory()));

  void resetSearch() {
    _debounce?.cancel();
    emit(SearchInitial(recentSearches: storageService.getSearchHistory()));
  }

  void resetSessionState() {
    resetSearch();
  }

  void search(String query, {bool isDebounced = true}) {
    if (query.trim().isEmpty) {
      resetSearch();
      return;
    }

    if (isDebounced) {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _performSearch(query.trim());
      });
    } else {
      _performSearch(query.trim());
    }
  }

  Future<void> _performSearch(String query) async {
    emit(SearchLoading());
    try {
      final resultsFuture = repository.searchTracks(query: query);
      final artistsFuture = repository.searchArtists(query);
      final albumsFuture = repository.searchAlbums(query, limit: 14);

      final results = await resultsFuture;
      final artists = await artistsFuture;
      List<Map<String, dynamic>> albums = const [];
      try {
        albums = await albumsFuture;
      } catch (_) {}

      if (!isClosed) {
        // Save to history only on successful actual search
        await storageService.addSearchQuery(query);
        emit(
          SearchSuccess(
            results: results,
            artists: artists,
            albums: albums,
            query: query,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(const SearchError("Une erreur est survenue lors de la recherche."));
      }
    }
  }

  Future<void> clearHistory() async {
    await storageService.clearSearchHistory();
    if (state is SearchInitial) {
      emit(const SearchInitial(recentSearches: []));
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
