import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../home/data/repositories/catalog_repository.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../../core/utils/responsive_utils.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late CatalogRepository _repository;

  bool _isSearching = false;
  bool _isLoading = false;
  List<TrackModel> _searchResults = [];

  final List<String> _recentSearches = ["Rock", "Jazz", "Ambient", "Pop"];

  @override
  void initState() {
    super.initState();
    _repository = CatalogRepository(apiClient: ApiClient(storageService: StorageService()));
  }

  void _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
    });

    try {
      final results = await _repository.searchTracks(query: query.trim());
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: TextField(
          controller: _searchController,
          onSubmitted: _onSearch,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Rechercher un morceau, artiste...",
            prefixIcon: const Icon(Icons.search, color: AppColors.primary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _searchController.clear();
                      _onSearch('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: !_isSearching ? _buildBeforeSearchBody() : _buildSearchResultsBody(),
    );
  }

  Widget _buildBeforeSearchBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Recherches récentes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _recentSearches.map((term) {
              return ActionChip(
                backgroundColor: AppColors.surface,
                label: Text(term, style: const TextStyle(color: Colors.white)),
                onPressed: () {
                  _searchController.text = term;
                  _onSearch(term);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text("Genres à explorer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: ResponsiveUtils.getGridCrossAxisCount(context),
              childAspectRatio: 2.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildGenreCard("Rock", Colors.pinkAccent),
                _buildGenreCard("Pop", Colors.blueAccent),
                _buildGenreCard("Jazz", Colors.orangeAccent),
                _buildGenreCard("Electro", Colors.purpleAccent),
                _buildGenreCard("Hip-Hop", Colors.greenAccent),
                _buildGenreCard("Ambient", Colors.tealAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreCard(String name, Color color) {
    return GestureDetector(
      onTap: () {
        _searchController.text = name;
        _onSearch(name);
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.centerLeft,
        child: Text(
          name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildSearchResultsBody() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            "Résultats",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _buildTrackResultsList(),
        ),
      ],
    );
  }

  Widget _buildTrackResultsList() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text("Aucun résultat pour \"${_searchController.text}\"", style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final track = _searchResults[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: track.coverUrl.isNotEmpty
                ? CachedNetworkImage(imageUrl: track.coverUrl, width: 48, height: 48, fit: BoxFit.cover)
                : Container(width: 48, height: 48, color: AppColors.surface, child: const Icon(Icons.music_note, color: Colors.white70)),
          ),
          title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(track.artistName, style: const TextStyle(color: AppColors.textSecondary)),
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 32),
            onPressed: () {
              context.read<PlayerCubit>().playTrack(track, queue: _searchResults);
            },
          ),
        );
      },
    );
  }
}
