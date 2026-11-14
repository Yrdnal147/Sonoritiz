import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/artists_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sonoritiz_page_title.dart';

/// Vue réutilisable et multi-générationnelle de sélection d'artistes
/// avec filtres par univers musicaux, recherche Deezer en direct et animations fluides.
class SonoritizArtistPickerView extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> initialSelected;
  final int minRequired;
  final int maxAllowed;
  final Future<void> Function(List<String> selected) onSubmit;
  final String Function(int count, bool canProceed) submitLabelBuilder;
  final VoidCallback? onBack;

  const SonoritizArtistPickerView({
    super.key,
    required this.title,
    required this.subtitle,
    this.initialSelected = const [],
    this.minRequired = 3,
    this.maxAllowed = 30,
    required this.onSubmit,
    required this.submitLabelBuilder,
    this.onBack,
  });

  @override
  State<SonoritizArtistPickerView> createState() =>
      _SonoritizArtistPickerViewState();
}

class _SonoritizArtistPickerViewState extends State<SonoritizArtistPickerView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final Dio _deezerDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );

  late final List<String> _selectedNames;
  final Map<String, String> _resolvedPictures = {};
  List<Map<String, String>> _remoteSearchResults = [];
  String _selectedCategory = 'Tous';
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isSubmitting = false;
  Timer? _debounce;

  late final AnimationController _entryController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _selectedNames = List<String>.from(widget.initialSelected);
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fadeIn = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _entryController.forward();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _entryController.dispose();
    _searchController.dispose();
    _deezerDio.close();
    super.dispose();
  }

  void _onSearchChanged(String raw) {
    setState(() => _searchQuery = raw.trim());
    _debounce?.cancel();
    if (_searchQuery.length < 2) {
      setState(() {
        _remoteSearchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 340), () async {
      setState(() => _isSearching = true);
      try {
        final res = await _deezerDio.get(
          'https://api.deezer.com/search/artist',
          queryParameters: {'q': _searchQuery, 'limit': 24},
        );
        if (!mounted) return;
        if (res.statusCode == 200 && res.data is Map && res.data['data'] is List) {
          final parsed = <Map<String, String>>[];
          for (final rawArtist in (res.data['data'] as List).whereType<Map>()) {
            final name = (rawArtist['name'] ?? '').toString().trim();
            final pic = (rawArtist['picture_medium'] ??
                    rawArtist['picture_xl'] ??
                    rawArtist['picture'] ??
                    '')
                .toString()
                .trim();
            if (name.isNotEmpty) {
              if (pic.isNotEmpty) {
                _resolvedPictures[name.toLowerCase()] = pic;
              }
              parsed.add({'name': name, 'imageUrl': pic});
            }
          }
          setState(() {
            _remoteSearchResults = parsed;
            _isSearching = false;
          });
          return;
        }
      } catch (_) {}
      if (mounted) setState(() => _isSearching = false);
    });
  }

  void _toggleArtist(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;

    final existingIdx = _selectedNames.indexWhere(
      (n) => n.toLowerCase() == clean.toLowerCase(),
    );

    setState(() {
      if (existingIdx >= 0) {
        _selectedNames.removeAt(existingIdx);
      } else if (_selectedNames.length < widget.maxAllowed) {
        _selectedNames.add(clean);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum ${widget.maxAllowed} artistes atteint.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    });
  }

  bool _isSelected(String name) {
    final lower = name.trim().toLowerCase();
    return _selectedNames.any((n) => n.toLowerCase() == lower);
  }

  List<Map<String, String>> _buildVisibleArtists() {
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final localMatches = ArtistsData.getArtistsForCategory('Tous')
          .where((a) => (a['name'] ?? '').toLowerCase().contains(q))
          .toList();

      final merged = <Map<String, String>>[..._remoteSearchResults];
      final seen = merged
          .map((a) => (a['name'] ?? '').trim().toLowerCase())
          .toSet();
      for (final local in localMatches) {
        final key = (local['name'] ?? '').trim().toLowerCase();
        if (seen.add(key)) merged.add(local);
      }
      return merged;
    }

    return ArtistsData.getArtistsForCategory(_selectedCategory).take(75).toList();
  }

  Future<void> _handleConfirm() async {
    if (_selectedNames.length < widget.minRequired || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(List<String>.from(_selectedNames));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleArtists = _buildVisibleArtists();
    final bool canProceed = _selectedNames.length >= widget.minRequired;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec soulignement orange Signature Sonoritiz
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.onBack != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10, top: 2),
                        child: IconButton(
                          onPressed: widget.onBack,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SonoritizPageTitle(
                            title: widget.title,
                            padding: EdgeInsets.zero,
                            fontSize: 25,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Barre de recherche en direct
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un artiste (Aznavour, Mozart, Burna Boy...)',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.40),
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 21,
                    ),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : (_searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null),
                    filled: true,
                    fillColor: const Color(0xFF14141A),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

              // Filtres par univers musicaux (toutes générations)
              if (_searchQuery.isEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: ArtistsData.artistCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = ArtistsData.artistCategories[index];
                      final active = cat == _selectedCategory;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : const Color(0xFF16161C),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: active ? Colors.black : Colors.white70,
                              fontSize: 12.5,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Ruban des artistes sélectionnés
              if (_selectedNames.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedNames.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final name = _selectedNames[idx];
                      return GestureDetector(
                        onTap: () => _toggleArtist(name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.close_rounded,
                                color: Colors.black,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Grille d'artistes animée
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 108),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: visibleArtists.length,
                  itemBuilder: (context, idx) {
                    final item = visibleArtists[idx];
                    final name = (item['name'] ?? '').trim();
                    final imageUrl = _resolvedPictures[name.toLowerCase()] ??
                        (item['imageUrl'] ?? '').trim();
                    final selected = _isSelected(name);

                    return GestureDetector(
                      onTap: () => _toggleArtist(name),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: AnimatedScale(
                              scale: selected ? 1.04 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.primary
                                            : Colors.white.withValues(alpha: 0.14),
                                        width: selected ? 2.8 : 1.0,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Container(
                                        color: const Color(0xFF1A1A22),
                                        width: double.infinity,
                                        height: double.infinity,
                                        child: imageUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    _ArtistInitialAvatar(name: name),
                                              )
                                            : _ArtistInitialAvatar(name: name),
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Positioned(
                                      right: 2,
                                      bottom: 2,
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.black,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected ? AppColors.primary : Colors.white,
                              fontSize: 12.5,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canProceed && !_isSubmitting ? _handleConfirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canProceed ? AppColors.primary : const Color(0xFF23232A),
                disabledBackgroundColor: const Color(0xFF1D1D24),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      widget.submitLabelBuilder(_selectedNames.length, canProceed),
                      style: TextStyle(
                        color: canProceed ? Colors.black : Colors.white54,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistInitialAvatar extends StatelessWidget {
  final String name;

  const _ArtistInitialAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
