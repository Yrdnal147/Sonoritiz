import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/constants/artists_data.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/home_cubit.dart';

class SelectArtistsScreen extends StatefulWidget {
  const SelectArtistsScreen({Key? key}) : super(key: key);

  @override
  State<SelectArtistsScreen> createState() => _SelectArtistsScreenState();
}

class _SelectArtistsScreenState extends State<SelectArtistsScreen> {
  late StorageService _storageService;
  final Set<String> _selectedArtists = {};
  
  // Moteur de recherche local
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _filteredArtists = [];

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _selectedArtists.addAll(_storageService.getFavoriteArtists());
    _filteredArtists = ArtistsData.globalArtists;

    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      setState(() {
        if (query.isEmpty) {
          _filteredArtists = ArtistsData.globalArtists;
        } else {
          _filteredArtists = ArtistsData.globalArtists.where((artist) {
            return artist['name']!.toLowerCase().contains(query);
          }).toList();
        }
      });
    });
  }

  Future<void> _saveAndExit() async {
    // On sauvegarde via le HomeCubit pour déclencher la mise à jour dynamique des recommandations
    await context.read<HomeCubit>().saveFavoriteArtists(_selectedArtists.toList());
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Vos artistes préférés", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text("${_selectedArtists.length} / 25 sélectionnés", style: const TextStyle(color: AppColors.primary, fontSize: 13)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveAndExit,
            child: const Text("Terminer", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Rechercher un artiste...",
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: _filteredArtists.length,
        itemBuilder: (context, index) {
          final artist = _filteredArtists[index];
          final name = artist['name']!;
          final imageUrl = artist['imageUrl']!;
          final isSelected = _selectedArtists.contains(name);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedArtists.remove(name);
                } else {
                  if (_selectedArtists.length < 25) {
                    _selectedArtists.add(name);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Vous avez atteint la limite de 25 artistes.")),
                    );
                  }
                }
              });
            },
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primary.withOpacity(0.3) : AppColors.surfaceLight,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                errorWidget: (context, url, error) => Center(
                                  child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                                ),
                              )
                            : Center(
                                child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                              ),
                      ),
                    ),
                    if (isSelected)
                      const Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.check, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
