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
      final results = await repository.searchTracks(query: query);
      
      if (!isClosed) {
        // Save to history only on successful actual search
        await storageService.addSearchQuery(query);
        emit(SearchSuccess(results: results, query: query));
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
      emit(SearchInitial(recentSearches: []));
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
