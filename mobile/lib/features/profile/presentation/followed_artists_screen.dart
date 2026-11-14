import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../home/data/repositories/catalog_repository.dart';

class FollowedArtistsScreen extends StatefulWidget {
  final VoidCallback? onArtistsChanged;

  const FollowedArtistsScreen({super.key, this.onArtistsChanged});

  @override
  State<FollowedArtistsScreen> createState() => _FollowedArtistsScreenState();
}

class _FollowedArtistsScreenState extends State<FollowedArtistsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final CatalogRepository _catalogRepository;
  List<String> _followedArtists = [];
  final Map<String, Map<String, dynamic>> _artistDetailsCache = {};
  String _searchQuery = '';
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _catalogRepository = CatalogRepository(
      apiClient: ApiClient(storageService: StorageService()),
    );
    _loadFollowedArtists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadFollowedArtists() {
    final list = StorageService().getFavoriteArtists();
    setState(() {
      _followedArtists = List<String>.from(list);
    });
    for (final artist in _followedArtists) {
      _fetchArtistDetails(artist);
    }
  }

  Future<void> _fetchArtistDetails(String name) async {
    if (_artistDetailsCache.containsKey(name)) return;
    try {
      final details = await _catalogRepository.getArtistDetailsDeezer(name);
      if (mounted && details.isNotEmpty) {
        setState(() {
          _artistDetailsCache[name] = details;
        });
      }
    } catch (_) {}
  }

  String _formatFans(dynamic fans) {
    final count = int.tryParse((fans ?? '0').toString()) ?? 0;
    if (count <= 0) return 'Artiste vérifié';
    final s = count.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(s[i]);
    }
    return '${buffer.toString()} auditeurs / mois';
  }

  Future<void> _toggleFollow(String artistName) async {
    final nowFollowed = await StorageService().toggleFollowArtist(artistName);
    widget.onArtistsChanged?.call();
    if (!mounted) return;
    setState(() {
      if (!nowFollowed) {
        _followedArtists.removeWhere(
          (a) => a.trim().toLowerCase() == artistName.trim().toLowerCase(),
        );
      } else {
        _followedArtists.add(artistName);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
        content: Text(
          nowFollowed
              ? 'Vous suivez à nouveau $artistName'
              : 'Vous ne suivez plus $artistName',
          style: const TextStyle(color: Colors.white),
        ),
        action: !nowFollowed
            ? SnackBarAction(
                label: 'Annuler',
                textColor: AppColors.primary,
                onPressed: () => _toggleFollow(artistName),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _followedArtists.where((name) {
      if (_searchQuery.trim().isEmpty) return true;
      return name.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 68,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SonoritizPageTitle(
              title: "Mes Artistes Suivis",
              fontSize: 19,
            ),
            const SizedBox(height: 3),
            Text(
              "${_followedArtists.length} artiste${_followedArtists.length != 1 ? 's' : ''} suivi${_followedArtists.length != 1 ? 's' : ''}",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isGridView ? "Vue liste" : "Vue grille",
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: Colors.white70,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onPressed: () async {
                await context.push('/select_artists');
                _loadFollowedArtists();
                widget.onArtistsChanged?.call();
              },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text(
                "Ajouter",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Barre de recherche
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Rechercher parmi vos artistes...",
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white60),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.people_outline_rounded,
                                  size: 52,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? "Aucun artiste trouvé"
                                    : "Vous ne suivez encore aucun artiste",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Suivez vos artistes favoris pour personnaliser vos recommandations et retrouver leurs profils en un clin d'œil.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 22),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size(210, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: () async {
                                  await context.push('/select_artists');
                                  _loadFollowedArtists();
                                  widget.onArtistsChanged?.call();
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text(
                                  "Découvrir des artistes",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _isGridView
                        ? GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final name = filtered[index];
                              return _buildArtistGridCard(name, index);
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final name = filtered[index];
                              return _buildArtistListCard(name, index);
                            },
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArtistListCard(String artistName, int index) {
    final details = _artistDetailsCache[artistName];
    final picUrl = (details?['picture_xl'] ?? details?['picture_medium'] ?? '').toString();
    final fansText = _formatFans(details?['nb_fan']);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/artist', extra: {'name': artistName}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.45), width: 1.5),
              ),
              child: ClipOval(
                child: picUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: picUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildFallbackAvatar(artistName),
                      )
                    : _buildFallbackAvatar(artistName),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.verified_rounded, color: AppColors.primary, size: 15),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    fansText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _toggleFollow(artistName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, color: AppColors.primary, size: 15),
                    SizedBox(width: 4),
                    Text(
                      "Suivi",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 35).ms).slideX(begin: 0.04, end: 0);
  }

  Widget _buildArtistGridCard(String artistName, int index) {
    final details = _artistDetailsCache[artistName];
    final picUrl = (details?['picture_xl'] ?? details?['picture_medium'] ?? '').toString();
    final fansText = _formatFans(details?['nb_fan']);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/artist', extra: {'name': artistName}),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.45), width: 2),
              ),
              child: ClipOval(
                child: picUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: picUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildFallbackAvatar(artistName),
                      )
                    : _buildFallbackAvatar(artistName),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              fansText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _toggleFollow(artistName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: const Text(
                  "Suivi ✓",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 35).ms).scale(begin: const Offset(0.96, 0.96));
  }

  Widget _buildFallbackAvatar(String name) {
    return Container(
      color: AppColors.surfaceLight,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
    );
  }
}
