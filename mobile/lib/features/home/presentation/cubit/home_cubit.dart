import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/catalog_repository.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final CatalogRepository repository;

  HomeCubit({required this.repository}) : super(HomeInitial());

  Future<void> loadHomeData() async {
    emit(HomeLoading());
    try {
      final trending = await repository.getTrendingTracks(limit: 10);
      final newReleases = await repository.searchTracks(query: 'new', limit: 10);
      final genres = await repository.getGenres();

      if (isClosed) return;
      emit(HomeLoaded(
        trendingTracks: trending,
        newReleases: newReleases,
        genres: genres,
      ));
    } catch (e, stack) {
      if (isClosed) return;
      print('=== ERREUR HOME CUBIT ===');
      print(e);
      print(stack);
      emit(HomeError("Impossible de charger les données de l'accueil."));
    }
  }
}
