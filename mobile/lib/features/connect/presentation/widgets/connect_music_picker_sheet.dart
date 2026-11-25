import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../home/data/repositories/catalog_repository.dart';
import '../../../library/data/repositories/library_repository.dart';
import '../../../library/presentation/cubit/library_cubit.dart';
import '../../../library/presentation/cubit/library_state.dart';
import '../../../player/data/models/track_model.dart';
import '../../../player/presentation/cubit/player_cubit.dart';
import '../cubit/connect_cubit.dart';

class ConnectMusicPickerSheet extends StatefulWidget {
  final bool isHost;
  final ConnectCubit connectCubit;
  final LibraryCubit? libraryCubit;

  const ConnectMusicPickerSheet({
    super.key,
    required this.isHost,
    required this.connectCubit,
    this.libraryCubit,
  });

  static Future<void> show(BuildContext context, {required bool isHost}) {
    final connectCubit = context.read<ConnectCubit>();
    LibraryCubit? libCubit;
    try {
      libCubit = context.read<LibraryCubit>();
      if (libCubit.state is LibraryInitial) {
        libCubit.loadLibraryData();
      }
    } catch (_) {}

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        Widget sheet = ConnectMusicPickerSheet(
          isHost: isHost,
          connectCubit: connectCubit,
          libraryCubit: libCubit,
        );
        if (libCubit != null) {
          sheet = BlocProvider<LibraryCubit>.value(
            value: libCubit,
            child: sheet,
          );
        }
        return BlocProvider<ConnectCubit>.value(
          value: connectCubit,
          child: sheet,
        );
      },
    );
  }

  @override
  State<ConnectMusicPickerSheet> createState() =>
      _ConnectMusicPickerSheetState();
}

class _ConnectMusicPickerSheetState extends State<ConnectMusicPickerSheet> {
  final CatalogRepository _catalogRepository = CatalogRepository();
  final TextEditingController _albumSearchCtrl = TextEditingController();
  final TextEditingController _trackSearchCtrl = TextEditingController();
  Timer? _albumDebounce;
  Timer? _trackDebounce;

  int _selectedTab = 0; // 0: Playlists, 1: Albums, 2: Sons
  bool _isCreatingPlaylist = false;

  // État création rapide de playlist
  final TextEditingController _newPlaylistNameCtrl = TextEditingController();
  final TextEditingController _newPlaylistTrackQueryCtrl =
      TextEditingController();
  Timer? _createPlaylistDebounce;
  List<TrackModel> _createSearchResults = const [];
  final List<TrackModel> _selectedNewPlaylistTracks = [];
  bool _isSavingPlaylist = false;

  // État recherche Albums
  bool _loadingAlbums = false;
  String? _loadingAlbumId;
  List<Map<String, dynamic>> _albumResults = const [];
  List<Map<String, dynamic>> _defaultAlbums = const [];

  // État recherche Sons
  bool _loadingTracks = false;
  List<TrackModel> _trackResults = const [];
  List<TrackModel> _defaultTracks = const [];

  @override
  void initState() {
    super.initState();
    _loadInitialCatalogData();
  }

  Future<void> _loadInitialCatalogData() async {
    try {
      final results = await Future.wait([
        _catalogRepository.getNewAlbumReleasesDeezer(limit: 12),
        _catalogRepository.getTrendingTracks(limit: 18),
      ]);
      if (!mounted) return;
      setState(() {
        _defaultAlbums = results[0] as List<Map<String, dynamic>>;
        _defaultTracks = results[1] as List<TrackModel>;
        _createSearchResults = _defaultTracks;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _albumDebounce?.cancel();
    _trackDebounce?.cancel();
    _createPlaylistDebounce?.cancel();
    _albumSearchCtrl.dispose();
    _trackSearchCtrl.dispose();
    _newPlaylistNameCtrl.dispose();
    _newPlaylistTrackQueryCtrl.dispose();
    super.dispose();
  }

  void _onAlbumQueryChanged(String q) {
    _albumDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _albumResults = const [];
        _loadingAlbums = false;
      });
      return;
    }
    setState(() => _loadingAlbums = true);
    _albumDebounce = Timer(const Duration(milliseconds: 380), () async {
      final res = await _catalogRepository.searchAlbums(q.trim(), limit: 22);
      if (!mounted) return;
      setState(() {
        _albumResults = res;
        _loadingAlbums = false;
      });
    });
  }

  void _onTrackQueryChanged(String q) {
    _trackDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _trackResults = const [];
        _loadingTracks = false;
      });
      return;
    }
    setState(() => _loadingTracks = true);
    _trackDebounce = Timer(const Duration(milliseconds: 350), () async {
      final res = await _catalogRepository.searchTracks(
        query: q.trim(),
        limit: 28,
      );
      if (!mounted) return;
      setState(() {
        _trackResults = res;
        _loadingTracks = false;
      });
    });
  }

  void _onCreatePlaylistQueryChanged(String q) {
    _createPlaylistDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _createSearchResults = _defaultTracks);
      return;
    }
    _createPlaylistDebounce =
        Timer(const Duration(milliseconds: 350), () async {
      final res = await _catalogRepository.searchTracks(
        query: q.trim(),
        limit: 24,
      );
      if (!mounted) return;
      setState(() => _createSearchResults = res);
    });
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _handleSelectPlaylist(PlaylistModel playlist) async {
    if (playlist.tracks.isEmpty) {
      _showToast("Cette playlist ne contient pas encore de titres.");
      return;
    }
    HapticFeedback.mediumImpact();
    if (widget.isHost) {
      Navigator.of(context).pop();
      await widget.connectCubit.hostPlayTrackList(
        playlist.tracks,
        title: playlist.name,
      );
    } else {
      Navigator.of(context).pop();
      await widget.connectCubit.suggestPlaylist(playlist);
      _showToast("Playlist « ${playlist.name} » suggérée à l'hôte !");
    }
  }

  Future<void> _handleSaveAndLaunchNewPlaylist() async {
    final name = _newPlaylistNameCtrl.text.trim();
    if (name.isEmpty) {
      _showToast("Donnez un nom à votre playlist.");
      return;
    }
    if (_selectedNewPlaylistTracks.isEmpty) {
      _showToast("Sélectionnez au moins un son.");
      return;
    }

    setState(() => _isSavingPlaylist = true);
    try {
      PlaylistModel createdPlaylist = PlaylistModel(
        id: -DateTime.now().millisecondsSinceEpoch,
        name: name,
        coverUrl: _selectedNewPlaylistTracks.first.coverUrl,
        tracksCount: _selectedNewPlaylistTracks.length,
        tracks: List<TrackModel>.from(_selectedNewPlaylistTracks),
      );

      final libCubit = widget.libraryCubit;
      if (libCubit != null) {
        final saved = await libCubit.createPlaylist(
          name,
          coverUrl: _selectedNewPlaylistTracks.first.coverUrl,
        );
        await libCubit.addMultipleTracksToPlaylist(
          saved.id,
          _selectedNewPlaylistTracks,
        );
        createdPlaylist = saved.copyWith(
          tracks: List<TrackModel>.from(_selectedNewPlaylistTracks),
          tracksCount: _selectedNewPlaylistTracks.length,
          coverUrl: saved.coverUrl.isNotEmpty
              ? saved.coverUrl
              : _selectedNewPlaylistTracks.first.coverUrl,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      if (widget.isHost) {
        await widget.connectCubit.hostPlayTrackList(
          createdPlaylist.tracks,
          title: createdPlaylist.name,
        );
      } else {
        await widget.connectCubit.suggestPlaylist(createdPlaylist);
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPlaylist = false);
      }
    }
  }

  Future<void> _handleSelectAlbum(Map<String, dynamic> album) async {
    final rawId = album['id'];
    final int? albumId =
        rawId is int ? rawId : int.tryParse((rawId ?? '').toString());
    if (albumId == null) return;

    final String title = (album['title'] ?? 'Album').toString();
    final String artistName =
        (album['artist_name'] ?? album['artist'] ?? 'Artiste').toString();
    final String cover = (album['cover'] ?? album['cover_url'] ?? '').toString();

    setState(() => _loadingAlbumId = albumId.toString());
    try {
      final tracks = await _catalogRepository.getAlbumTracksDeezer(
        albumId,
        cover,
        artistName,
        albumTitle: title,
      );
      if (!mounted) return;
      if (tracks.isEmpty) {
        _showToast("Impossible de charger les titres de cet album.");
        return;
      }
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      if (widget.isHost) {
        await widget.connectCubit.hostPlayTrackList(
          tracks,
          title: title,
        );
      } else {
        await widget.connectCubit.suggestAlbum(
          title: title,
          artistName: artistName,
          coverUrl: cover,
          tracks: tracks,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAlbumId = null);
      }
    }
  }

  Future<void> _handleSelectTrack(
    TrackModel track, {
    bool addNextOnly = false,
  }) async {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    if (widget.isHost) {
      if (addNextOnly) {
        await widget.connectCubit.hostAddTrackNext(track);
      } else {
        final currentQueue =
            context.read<PlayerCubit>().state.queue.isNotEmpty
                ? List<TrackModel>.from(context.read<PlayerCubit>().state.queue)
                : <TrackModel>[track];
        if (!currentQueue.any((t) => t.id == track.id)) {
          currentQueue.insert(0, track);
        }
        final idx = currentQueue.indexWhere((t) => t.id == track.id);
        await widget.connectCubit.hostPlayTrackList(
          currentQueue,
          title: track.albumName.isNotEmpty && track.albumName != 'YouTube Audio'
              ? track.albumName
              : 'Sélection de l’hôte',
          startIndex: idx >= 0 ? idx : 0,
        );
      }
    } else {
      await widget.connectCubit.suggestTrack(track);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double sheetHeight = mediaQuery.size.height * 0.86;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E12),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  if (_isCreatingPlaylist)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _isCreatingPlaylist = false),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCreatingPlaylist
                              ? "Nouvelle playlist du salon"
                              : (widget.isHost
                                  ? "Animer le salon Connect"
                                  : "Suggérer à l'hôte"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isCreatingPlaylist
                              ? "Nommez votre playlist et choisissez les sons à partager."
                              : (widget.isHost
                                  ? "Lancez une playlist, un album ou un son visible par tous."
                                  : "Proposez un son, un album ou une playlist sans couper l'écoute."),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isCreatingPlaylist) ...[
              _buildTabs(),
              const SizedBox(height: 12),
              Expanded(
                child: IndexedStack(
                  index: _selectedTab,
                  children: [
                    _buildPlaylistsTab(),
                    _buildAlbumsTab(),
                    _buildTracksTab(),
                  ],
                ),
              ),
            ] else
              Expanded(child: _buildCreatePlaylistView()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final labels = ['Playlists', 'Albums', 'Sons'];
    final icons = [
      Icons.queue_music_rounded,
      Icons.album_rounded,
      Icons.music_note_rounded,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF17171D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final active = _selectedTab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icons[i],
                        size: 16,
                        color: active
                            ? Colors.black
                            : Colors.white.withValues(alpha: 0.65),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        labels[i],
                        style: TextStyle(
                          color: active
                              ? Colors.black
                              : Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 46,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.11),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 19,
            color: Colors.white.withValues(alpha: 0.50),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.36),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Icon(
                Icons.cancel_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    List<PlaylistModel> playlists = const [];
    List<TrackModel> favorites = const [];
    final libCubit = widget.libraryCubit;
    if (libCubit != null) {
      final libState = context.watch<LibraryCubit>().state;
      if (libState is LibraryLoaded) {
        playlists = libState.playlists;
        favorites = libState.favorites;
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        // Bouton création d'une nouvelle playlist directement dans Connect
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _isCreatingPlaylist = true);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.22),
                  const Color(0xFF17171D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.42),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Créer une nouvelle playlist",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isHost
                            ? "Composez et lancez votre sélection immédiatement"
                            : "Composez une playlist et suggérez-la à l'hôte",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (favorites.isNotEmpty) ...[
          _buildPlaylistTile(
            PlaylistModel(
              id: -999999,
              name: "Mes titres likés",
              coverUrl: favorites.first.coverUrl,
              tracksCount: favorites.length,
              tracks: favorites,
            ),
            subtitleOverride: "${favorites.length} coups de cœur",
          ),
          const SizedBox(height: 10),
        ],

        if (playlists.isEmpty && favorites.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                "Aucune playlist enregistrée.\nCréez-en une ci-dessus en quelques secondes !",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          )
        else
          ...playlists.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildPlaylistTile(p),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaylistTile(
    PlaylistModel playlist, {
    String? subtitleOverride,
  }) {
    final cover = playlist.coverUrl.isNotEmpty
        ? playlist.coverUrl
        : (playlist.tracks.isNotEmpty ? playlist.tracks.first.coverUrl : '');
    final count = playlist.tracks.isNotEmpty
        ? playlist.tracks.length
        : playlist.tracksCount;

    return GestureDetector(
      onTap: () => _handleSelectPlaylist(playlist),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF16161B),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            SonoritizArtwork(
              imageUrl: cover,
              width: 52,
              height: 52,
              borderRadius: 11,
              cacheMaxDimension: 150,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitleOverride ?? "$count titres",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.56),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: widget.isHost
                    ? Colors.white
                    : AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
                border: widget.isHost
                    ? null
                    : Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
              ),
              child: Text(
                widget.isHost ? "Lancer" : "Suggérer",
                style: TextStyle(
                  color: widget.isHost ? Colors.black : AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePlaylistView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF17171D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.40),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: _newPlaylistNameCtrl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: "Nom de la playlist (ex: Soirée Connect 🔥)",
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.36),
                  fontSize: 13.5,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ),
        _buildSearchField(
          controller: _newPlaylistTrackQueryCtrl,
          hint: "Rechercher des sons à ajouter...",
          onChanged: _onCreatePlaylistQueryChanged,
        ),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
            itemCount: _createSearchResults.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final t = _createSearchResults[index];
              final isSelected =
                  _selectedNewPlaylistTracks.any((item) => item.id == t.id);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      _selectedNewPlaylistTracks
                          .removeWhere((item) => item.id == t.id);
                    } else {
                      _selectedNewPlaylistTracks.add(t);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : const Color(0xFF16161B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Row(
                    children: [
                      SonoritizArtwork(
                        imageUrl: t.coverUrl,
                        width: 44,
                        height: 44,
                        borderRadius: 9,
                        cacheMaxDimension: 140,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.58),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        color: isSelected
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.45),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: GestureDetector(
              onTap:
                  _isSavingPlaylist ? null : _handleSaveAndLaunchNewPlaylist,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: _isSavingPlaylist
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        widget.isHost
                            ? "Créer & lancer dans le salon (${_selectedNewPlaylistTracks.length})"
                            : "Créer & suggérer à l'hôte (${_selectedNewPlaylistTracks.length})",
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumsTab() {
    final displayAlbums = _albumSearchCtrl.text.trim().isNotEmpty
        ? _albumResults
        : _defaultAlbums;

    return Column(
      children: [
        _buildSearchField(
          controller: _albumSearchCtrl,
          hint: "Rechercher un album ou un artiste...",
          onChanged: _onAlbumQueryChanged,
        ),
        Expanded(
          child: _loadingAlbums
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.3,
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  itemCount: displayAlbums.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final a = displayAlbums[index];
                    final idStr = (a['id'] ?? '').toString();
                    final isLoadingThis = _loadingAlbumId == idStr;
                    final title = (a['title'] ?? 'Album').toString();
                    final artist =
                        (a['artist_name'] ?? a['artist'] ?? 'Artiste')
                            .toString();
                    final cover =
                        (a['cover'] ?? a['cover_url'] ?? '').toString();

                    return GestureDetector(
                      onTap: isLoadingThis ? null : () => _handleSelectAlbum(a),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16161B),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            SonoritizArtwork(
                              imageUrl: cover,
                              width: 52,
                              height: 52,
                              borderRadius: 11,
                              cacheMaxDimension: 150,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.58),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isLoadingThis)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.isHost
                                      ? Colors.white
                                      : AppColors.primary
                                          .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(18),
                                  border: widget.isHost
                                      ? null
                                      : Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.4),
                                        ),
                                ),
                                child: Text(
                                  widget.isHost ? "Lancer" : "Suggérer",
                                  style: TextStyle(
                                    color: widget.isHost
                                        ? Colors.black
                                        : AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTracksTab() {
    final displayTracks = _trackSearchCtrl.text.trim().isNotEmpty
        ? _trackResults
        : _defaultTracks;

    return Column(
      children: [
        _buildSearchField(
          controller: _trackSearchCtrl,
          hint: "Rechercher un son ou un artiste...",
          onChanged: _onTrackQueryChanged,
        ),
        Expanded(
          child: _loadingTracks
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.3,
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  itemCount: displayTracks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final t = displayTracks[index];
                    return GestureDetector(
                      onTap: () => _handleSelectTrack(t),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16161B),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            SonoritizArtwork(
                              imageUrl: t.coverUrl,
                              width: 48,
                              height: 48,
                              borderRadius: 10,
                              cacheMaxDimension: 140,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.artistName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.58),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.isHost) ...[
                              GestureDetector(
                                onTap: () =>
                                    _handleSelectTrack(t, addNextOnly: true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.playlist_add_rounded,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  "Lire",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ] else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Text(
                                  "Suggérer",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
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
