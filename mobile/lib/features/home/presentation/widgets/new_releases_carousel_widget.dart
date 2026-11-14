import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/storage/json_cache.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../../core/widgets/sonoritiz_page_title.dart';
import '../../../library/presentation/cubit/library_cubit.dart';
import '../../../library/presentation/cubit/library_state.dart';

/// Nombre d'albums affichés dans le carrousel (le reste est visible via « Voir tout »).
const int _kCarouselMaxAlbums = 20;

/// Libellé relatif de la date de sortie (« Aujourd'hui », « Il y a 3 j »...).
String? _relativeReleaseLabel(dynamic raw) {
  final date = DateTime.tryParse((raw ?? '').toString());
  if (date == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days < 0) return 'À venir';
  if (days == 0) return "Aujourd'hui";
  if (days == 1) return 'Hier';
  if (days < 7) return 'Il y a $days j';
  if (days < 30) return 'Il y a ${days ~/ 7} sem.';
  if (days < 365) return 'Il y a ${days ~/ 30} mois';
  final years = days ~/ 365;
  return 'Il y a $years an${years > 1 ? 's' : ''}';
}

/// Sortie de moins de 30 jours (ou à venir).
bool _isFreshRelease(dynamic raw) {
  final date = DateTime.tryParse((raw ?? '').toString());
  if (date == null) return false;
  return DateTime.now().difference(date).inDays <= 30;
}

/// Badge principal : « Pour toi » (tes artistes), « Similaire » (artistes proches)
/// ou « Nouveau » (sortie de moins de 30 jours).
({String label, IconData icon})? _releaseBadge(Map<String, dynamic> album) {
  switch (album['source']) {
    case 'for_you':
      return (label: 'Pour toi', icon: Icons.headphones_rounded);
    case 'related':
      return (label: 'Similaire', icon: Icons.bubble_chart_rounded);
  }
  if (_isFreshRelease(album['release_date'])) {
    return (label: 'Nouveau', icon: Icons.fiber_new_rounded);
  }
  return null;
}

void _openReleaseAlbum(BuildContext context, Map<String, dynamic> album) {
  context.push('/album', extra: {
    'id': album['id'],
    'title': album['title'],
    'cover': album['cover'],
    'cover_xl': album['cover'],
    'artistName': album['artist_name'],
    'artist_name': album['artist_name'],
    'record_type': album['record_type'],
  });
}

Widget _buildReleaseBadgeChip(({String label, IconData icon}) badge, {double fontSize = 11}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(badge.icon, color: AppColors.primary, size: fontSize + 4),
        const SizedBox(width: 4),
        Text(
          badge.label,
          style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class NewReleasesCarouselWidget extends StatefulWidget {
  const NewReleasesCarouselWidget({super.key});

  @override
  State<NewReleasesCarouselWidget> createState() => _NewReleasesCarouselWidgetState();
}

class _NewReleasesCarouselWidgetState extends State<NewReleasesCarouselWidget> {
  late PageController _pageController;
  late CatalogRepository _catalogRepository;
  List<Map<String, dynamic>> _albums = [];
  bool _isLoading = true;
  double _currentPage = 0.0;

  String get _cacheKey =>
      'home_personalized_album_releases_v4_${StorageService().accountScope}';

  static final RegExp _artistSplitRegExp = RegExp(
    r'\s*(?:\bfeat\.?|\bft\.?|\bfeaturing\b|&|,|\bx\b)\s*',
    caseSensitive: false,
  );

  String _lastAccountScope = '';

  void _onFavoriteArtistsChanged() {
    if (!mounted) return;
    _loadAlbums(forceReload: true);
  }

  @override
  void initState() {
    super.initState();
    _lastAccountScope = StorageService().accountScope;
    StorageService.favoriteArtistsNotifier.addListener(_onFavoriteArtistsChanged);
    _pageController = PageController(viewportFraction: 0.70);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0.0;
      });
    });

    _catalogRepository = CatalogRepository(
      apiClient: ApiClient(storageService: StorageService()),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAlbums();
    });
  }

  /// Classe les artistes de l'utilisateur par affinité réelle
  /// (nombre d'écoutes + artistes suivis + Superlikes + favoris + historique).
  List<String> _rankPreferredArtists() {
    final Map<String, double> scores = {};
    final Map<String, String> displayNames = {};

    void addScore(String? raw, double points) {
      if (raw == null || raw.trim().isEmpty) return;
      for (final part in raw.split(_artistSplitRegExp)) {
        final name = part.replaceAll(RegExp(r'[\(\)\[\]]'), '').trim();
        if (name.length < 2) continue;
        final key = name.toLowerCase();
        displayNames.putIfAbsent(key, () => name);
        scores[key] = (scores[key] ?? 0) + points;
      }
    }

    final storage = StorageService();

    // a. Artistes suivis / favoris (priorité forte)
    for (final a in storage.getFavoriteArtists()) {
      addScore(a, 40);
    }

    // b. Artistes des Sonoritiz Superlikes
    try {
      for (final sl in storage.getSuperlikesRaw()) {
        final a = sl['artist_name'] ?? sl['artist'] ?? sl['track']?['artist_name'];
        if (a is String) addScore(a, 15);
      }
    } catch (_) {}

    // c. Historique des écoutes cumulées (1 point par écoute)
    try {
      for (final item in storage.getLifetimeTrackPlaysRaw().values) {
        if (item is Map) {
          final t = item['track'];
          final count = item['count'] is int ? item['count'] as int : 1;
          if (t is Map) {
            final a = t['artist_name'] ?? t['artist'];
            if (a is String) addScore(a, count.toDouble());
          }
        }
      }
    } catch (_) {}

    // d. Favoris et historique récent depuis LibraryCubit
    if (mounted) {
      try {
        final libState = context.read<LibraryCubit>().state;
        if (libState is LibraryLoaded) {
          for (final fav in libState.favorites) {
            addScore(fav.artistName, 5);
          }
          for (final h in libState.history) {
            addScore(h.track?.artistName, 1);
          }
        }
      } catch (_) {}
    }

    final ranked = scores.keys.toList()
      ..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    return ranked.map((k) => displayNames[k] ?? k).toList();
  }

  Future<void> _loadAlbums({bool forceReload = false}) async {
    final currentScope = StorageService().accountScope;
    if (forceReload || currentScope != _lastAccountScope) {
      _lastAccountScope = currentScope;
      if (mounted) {
        setState(() {
          _albums = [];
          _isLoading = true;
        });
      }
    }
    // 1. Dernier contenu connu en cache affiché instantanément
    final cached = await JsonCache.read(_cacheKey);
    if (cached is List && cached.isNotEmpty && mounted) {
      setState(() {
        _albums = cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _isLoading = false;
      });
    }

    // 2. Artistes de l'utilisateur classés par nombre d'écoutes
    final preferredArtists = _rankPreferredArtists();

    // 3. Tes artistes en premier, puis artistes similaires, puis grosses nouveautés du moment
    final albums = await _catalogRepository.getPersonalizedNewAlbumReleasesDeezer(
      preferredArtists: preferredArtists,
      limit: 60,
    );

    if (albums.isNotEmpty) {
      JsonCache.write(_cacheKey, albums);
    }
    if (mounted) {
      setState(() {
        if (albums.isNotEmpty) _albums = albums;
        _isLoading = false;
      });
    }
  }

  void _openAllReleases() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AllAlbumReleasesScreen(albums: List.of(_albums)),
      ),
    );
  }

  @override
  void dispose() {
    StorageService.favoriteArtistsNotifier.removeListener(_onFavoriteArtistsChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (_albums.isEmpty) {
      return const SizedBox.shrink();
    }

    final carouselAlbums = _albums.take(_kCarouselMaxAlbums).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Albums à venir & Sorties",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Nouveautés éditoriales & prochaines sorties",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openAllReleases,
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                child: Text(
                  'Voir tout (${_albums.length})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            itemCount: carouselAlbums.length,
            itemBuilder: (context, index) {
              final album = carouselAlbums[index];
              final double value = (index - _currentPage).abs();
              final double scale = 1.0 - (value * 0.12).clamp(0.0, 0.25);
              final badge = _releaseBadge(album);
              final dateLabel = _relativeReleaseLabel(album['release_date']);

              return GestureDetector(
                onTap: () => _openReleaseAlbum(context, album),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        if (value < 0.5)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Cover Image
                          SonoritizArtwork(
                            imageUrl: album['cover'] ?? '',
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 0,
                          ),

                          // Gradient sombre pour lisibilité
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.15),
                                  Colors.black.withValues(alpha: 0.75),
                                  Colors.black.withValues(alpha: 0.95),
                                ],
                                stops: const [0.0, 0.45, 0.75, 1.0],
                              ),
                            ),
                          ),

                          // Badge Pour toi / Similaire / Nouveau
                          if (badge != null)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: _buildReleaseBadgeChip(badge),
                            ),

                          // Badge Format (Album / EP / Single)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.album_rounded, color: Colors.white70, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    (album['record_type']?.toString().toUpperCase() ?? 'ALBUM'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Titre de l'album, nom de l'artiste & date de sortie
                          Positioned(
                            bottom: 14,
                            left: 14,
                            right: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  album['title'] ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    height: 1.15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (album['artist_picture'] != null &&
                                        (album['artist_picture'] as String).isNotEmpty) ...[
                                      SonoritizArtwork(
                                        imageUrl: album['artist_picture'],
                                        width: 20,
                                        height: 20,
                                        shape: BoxShape.circle,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Flexible(
                                      child: Text(
                                        album['artist_name'] ?? 'Artiste inconnu',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (dateLabel != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    dateLabel,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Grille complète de toutes les sorties albums trouvées (ouverte via « Voir tout »).
class _AllAlbumReleasesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> albums;

  const _AllAlbumReleasesScreen({required this.albums});

  @override
  Widget build(BuildContext context) {
    final firstCover =
        albums.isNotEmpty ? (albums.first['cover'] ?? '').toString() : '';

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const SonoritizPageTitle(
          title: 'Albums à venir & Sorties',
          fontSize: 22,
        ),
      ),
      body: SonoritizCoverAtmosphere(
        coverUrl: firstCover,
        child: SafeArea(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 18,
              crossAxisSpacing: 14,
              childAspectRatio: 0.70,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              final badge = _releaseBadge(album);
              final dateLabel = _relativeReleaseLabel(album['release_date']);
              final recordType = (album['record_type']?.toString().toUpperCase() ?? 'ALBUM');

              return GestureDetector(
                onTap: () => _openReleaseAlbum(context, album),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: SonoritizArtwork(
                              imageUrl: album['cover'] ?? '',
                              width: double.infinity,
                              height: double.infinity,
                              borderRadius: 14,
                              cacheMaxDimension: 400,
                            ),
                          ),
                          if (badge != null)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: _buildReleaseBadgeChip(badge, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      album['title'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      album['artist_name'] ?? 'Artiste inconnu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel != null ? '$recordType • $dateLabel' : recordType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
