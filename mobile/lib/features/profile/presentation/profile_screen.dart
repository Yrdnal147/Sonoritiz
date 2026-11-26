import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/session_coordinator.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/data/repositories/catalog_repository.dart';
import '../../library/presentation/cubit/library_cubit.dart';
import '../../library/presentation/cubit/library_state.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/superlike_cubit.dart';
import '../../player/presentation/cubit/superlike_state.dart';
import '../../../core/widgets/superlike_torch_badge.dart';
import '../../../core/widgets/sonoritiz_dynamic_background.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../../core/widgets/track_context_menu.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storage = StorageService();
  final CatalogRepository _catalogRepository = CatalogRepository();

  String _username = '';
  String _email = '';
  String _bio = '';
  String? _profileImagePath;
  int _localFilesCount = 0;
  List<String> _followedArtists = [];
  Map<String, String> _artistImages = {};
  bool _pushNotifications = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await _storage.init();
    final followed = _storage.getFollowedArtists();
    final rawBio = _storage.userBio;
    final cleanBio = rawBio == 'Passionné de son studio & explorateur musical 🎧'
        ? ''
        : rawBio;
    final notifications = _storage.pushNotificationsEnabled;

    setState(() {
      _username = _storage.username.isNotEmpty ? _storage.username : 'Mélomane';
      _email = _storage.email.isNotEmpty ? _storage.email : '';
      _bio = cleanBio;
      _profileImagePath = _storage.getProfileImagePath();
      _localFilesCount = _storage.getLocalFiles().length;
      _followedArtists = followed;
      _pushNotifications = notifications;
      _loaded = true;
    });

    _loadArtistPictures(followed);
  }

  Future<void> _loadArtistPictures(List<String> artists) async {
    final Map<String, String> map = Map<String, String>.from(_artistImages);
    final toFetch = artists.where((a) => !map.containsKey(a)).toList();
    if (toFetch.isEmpty) return;

    for (int i = 0; i < toFetch.length; i += 6) {
      final chunk = toFetch.sublist(
        i,
        (i + 6 > toFetch.length) ? toFetch.length : i + 6,
      );
      await Future.wait(chunk.map((artist) async {
        try {
          final details = await _catalogRepository.getArtistDetailsDeezer(artist);
          final pic = (details['picture_xl'] ?? details['picture_medium'] ?? '').toString();
          if (pic.isNotEmpty) {
            map[artist] = pic;
          }
        } catch (_) {}
      }));
      if (mounted) {
        setState(() {
          _artistImages = Map<String, String>.from(map);
        });
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        final dir = await getApplicationDocumentsDirectory();
        final File newImage = File(
          '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await File(pickedFile.path).copy(newImage.path);

        await _storage.saveProfileImagePath(newImage.path);
        if (mounted) {
          setState(() {
            _profileImagePath = newImage.path;
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur lors de la sélection de l'image : $e");
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF16161C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Se déconnecter',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Souhaitez-vous vous déconnecter de ce compte ? Vos téléchargements et données locales seront conservés.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final libraryCubit = context.read<LibraryCubit>();
              await libraryCubit.syncPendingLocalPlaylistsNow();
              try {
                final googleSignIn = GoogleSignIn(
                  serverClientId:
                      '332358147050-fj2huukn8hcf40dukiuta1hc393lmh5a.apps.googleusercontent.com',
                );
                await googleSignIn.signOut();
              } catch (_) {}
              if (!mounted) return;
              await SessionCoordinator.handleLogout(context);
              if (mounted) {
                context.go('/login');
              }
            },
            child: const Text(
              'Déconnexion',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerStyleBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return ValueListenableBuilder<String>(
          valueListenable: StorageService.playerStyleNotifier,
          builder: (context, currentStyle, _) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C0E),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Apparence du lecteur',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPlayerStyleOptionCard(
                      id: 'vertical',
                      isSelected: currentStyle == 'vertical',
                      title: 'Signature Sonoritiz (Par défaut)',
                      subtitle: 'Pochette fondue, vibration couleur pochette et dock 5 outils',
                      icon: Icons.equalizer_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildPlayerStyleOptionCard(
                      id: 'default',
                      isSelected: currentStyle == 'default',
                      title: 'Classique Immersif',
                      subtitle: 'Fond flouté dynamique inspiré de la pochette',
                      icon: Icons.album_rounded,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlayerStyleOptionCard({
    required String id,
    required bool isSelected,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await _storage.setPlayerStyle(id);
        if (mounted) setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.white70,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SonoritizDynamicBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. En-tête épuré et aéré (sans boîte encadrée)
              SliverToBoxAdapter(
                child: _buildOpenProfileHeader(context),
              ),

              // 2. Compteurs en ligne fluides (remplace les 4 gros pavés étouffants)
              SliverToBoxAdapter(
                child: _buildInlineStatsStrip(context),
              ),

              // 3. Vos Superlikes (Section ouverte, uniquement si non vide ou discrète)
              SliverToBoxAdapter(
                child: _buildSuperlikesOpenSection(context),
              ),

              // 4. Vos titres les plus écoutés (Replay ouvert, vraies pochettes carrées)
              SliverToBoxAdapter(
                child: _buildTopListenedOpenSection(context),
              ),

              // 5. Artistes suivis
              if (_followedArtists.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildFollowedArtistsSection(context),
                ),

              // 6. Votre Empreinte Sonore (Rubrique originale 1 -> /sound-passport)
              SliverToBoxAdapter(
                child: _buildSonicPassportPreviewSection(context),
              ),

              // 7. Capsules & Temps Forts (Rubrique originale 2 -> /activity-capsules)
              SliverToBoxAdapter(
                child: _buildCapsulesPreviewSection(context),
              ),

              // 8. Préférences & Compte
              SliverToBoxAdapter(
                child: _buildSettingsSection(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenProfileHeader(BuildContext context) {
    final canPopRoute = GoRouter.maybeOf(context)?.canPop() ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canPopRoute) ...[
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
              const Expanded(
                child: SonoritizPageTitle(title: "Profil"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickProfileImage,
                child: Stack(
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: !kIsWeb &&
                                _profileImagePath != null &&
                                File(_profileImagePath!).existsSync()
                            ? Image.file(
                                File(_profileImagePath!),
                                fit: BoxFit.cover,
                              )
                            : _avatarFallback(82),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (_email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (_bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  await context.push('/edit-profile');
                  if (mounted) {
                    _loadProfile();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Text(
                    'Modifier',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStatsStrip(BuildContext context) {
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, libState) {
        final favCount = libState is LibraryLoaded ? libState.favorites.length : 0;
        final playlistCount = libState is LibraryLoaded ? libState.playlists.length : 0;
        final followedCount = _followedArtists.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  value: '$favCount',
                  label: 'Favoris',
                  onTap: () => context.push('/favorites'),
                ),
                _verticalStatDivider(),
                _buildStatColumn(
                  value: '$playlistCount',
                  label: 'Playlists',
                  onTap: () => context.push('/playlists_list'),
                ),
                _verticalStatDivider(),
                _buildStatColumn(
                  value: '$followedCount',
                  label: 'Artistes',
                  onTap: () => context.push('/followed-artists'),
                ),
                _verticalStatDivider(),
                _buildStatColumn(
                  value: '$_localFilesCount',
                  label: 'Locaux',
                  onTap: () => context.push('/local_audio'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn({
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalStatDivider() {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildSuperlikesOpenSection(BuildContext context) {
    return BlocBuilder<SuperlikeCubit, SuperlikeState>(
      builder: (context, slState) {
        final superlikes = slState.tracks;
        if (superlikes.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const SuperlikeTorchBadge(
                      size: TorchBadgeSize.small,
                      showBackground: false,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Superlikes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${superlikes.length}/20',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        context.read<PlayerCubit>().playTrack(
                              superlikes.first,
                              queue: superlikes,
                              source: 'Sonoritiz Superlikes',
                            );
                      },
                      child: const Text(
                        'Tout écouter',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 176,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: superlikes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final track = superlikes[index];
                    return GestureDetector(
                      onLongPress: () => TrackContextMenu.show(context, track),
                      onTap: () {
                        context.read<PlayerCubit>().playTrack(
                              track,
                              queue: superlikes,
                              source: 'Sonoritiz Superlikes',
                            );
                      },
                      child: SizedBox(
                        width: 126,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: track.coverUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: track.coverUrl,
                                      width: 126,
                                      height: 126,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          _coverFallback(126, 126),
                                    )
                                  : _coverFallback(126, 126),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11.5,
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
          ),
        );
      },
    );
  }

  Widget _buildTopListenedOpenSection(BuildContext context) {
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, state) {
        final libCubit = context.read<LibraryCubit>();
        final top10 = libCubit.getTopTracksSinceCreation(limit: 10);
        final allTracks = top10.map((e) => e.track).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Les plus écoutés',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        context.push('/stats', extra: true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Story',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () => context.push('/stats'),
                      child: Text(
                        'Replay ›',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (top10.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Vos statistiques d’écoute apparaîtront ici au fil de vos écoutes.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 176,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: top10.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final item = top10[index];
                      final rank = index + 1;

                      return GestureDetector(
                        onLongPress: () =>
                            TrackContextMenu.show(context, item.track),
                        onTap: () {
                          context.read<PlayerCubit>().playTrack(
                                item.track,
                                queue: allTracks,
                                source: 'Vos titres les plus écoutés',
                              );
                        },
                        child: SizedBox(
                          width: 126,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: item.track.coverUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: item.track.coverUrl,
                                            width: 126,
                                            height: 126,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                _coverFallback(126, 126),
                                          )
                                        : _coverFallback(126, 126),
                                  ),
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#$rank',
                                        style: TextStyle(
                                          color: rank == 1
                                              ? AppColors.primary
                                              : Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.track.artistName} • ${item.playCount} écoutes',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.48),
                                  fontSize: 11.5,
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
          ),
        );
      },
    );
  }

  Widget _buildFollowedArtistsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  'Artistes suivis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/followed-artists'),
                  child: Text(
                    'Voir tout ›',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _followedArtists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                final artistName = _followedArtists[index];
                final imageUrl = _artistImages[artistName] ?? '';

                return GestureDetector(
                  onTap: () => context.push(
                    '/artist',
                    extra: {'name': artistName},
                  ),
                  child: Column(
                    children: [
                      ClipOval(
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _avatarFallback(76, text: artistName[0]),
                              )
                            : _avatarFallback(76, text: artistName[0]),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  Widget _buildSonicPassportPreviewSection(BuildContext context) {
    final rawPlays = _storage.getLifetimeTrackPlaysRaw();
    int totalPlays = 0;
    final artistCounts = <String, int>{};
    int morning = 0;
    int afternoon = 0;
    int evening = 0;
    int night = 0;

    for (final entry in rawPlays.values) {
      if (entry is! Map) continue;
      final trackMap = entry['track'];
      if (trackMap is! Map) continue;
      final artist = (trackMap['artist_name'] ?? '').toString().trim();
      final count = entry['count'] is int ? entry['count'] as int : 1;
      totalPlays += count;
      if (artist.isNotEmpty) {
        artistCounts[artist] = (artistCounts[artist] ?? 0) + count;
      }
      final tsList = entry['play_timestamps'];
      if (tsList is List) {
        for (final ts in tsList) {
          final dt = DateTime.tryParse(ts.toString())?.toLocal();
          if (dt == null) continue;
          if (dt.hour >= 6 && dt.hour < 12) {
            morning++;
          } else if (dt.hour >= 12 && dt.hour < 18) {
            afternoon++;
          } else if (dt.hour >= 18 && dt.hour < 23) {
            evening++;
          } else {
            night++;
          }
        }
      }
    }

    String peakSlot = 'Soirée';
    int peakValue = evening;
    if (morning > peakValue) {
      peakValue = morning;
      peakSlot = 'Matin';
    }
    if (afternoon > peakValue) {
      peakValue = afternoon;
      peakSlot = 'Après-midi';
    }
    if (night > peakValue) {
      peakSlot = 'Nuit';
    }

    String leadArtist = '';
    int maxArtist = 0;
    artistCounts.forEach((k, v) {
      if (v > maxArtist) {
        maxArtist = v;
        leadArtist = k;
      }
    });

    final uniqueTracks = rawPlays.length;
    final diversityPct = uniqueTracks == 0
        ? 0
        : ((artistCounts.length / uniqueTracks) * 100).round().clamp(12, 100);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Votre Empreinte Sonore',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/sound-passport'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Passeport ›',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            totalPlays > 0
                ? 'Profil calculé sur $totalPlays écoutes mémorisées'
                : 'Horloge d’écoute, diversité et artistes repères',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => context.push('/sound-passport'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  bottom:
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _passportQuickCol(
                    label: 'Créneau phare',
                    value: totalPlays > 0 ? peakSlot : '—',
                  ),
                  _verticalStatDivider(),
                  _passportQuickCol(
                    label: 'Diversité',
                    value: totalPlays > 0 ? '$diversityPct%' : '—',
                  ),
                  _verticalStatDivider(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Signature #1',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            leadArtist.isNotEmpty ? leadArtist : 'À découvrir',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passportQuickCol({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsulesPreviewSection(BuildContext context) {
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, libState) {
        final favAlbumsCount =
            libState is LibraryLoaded ? libState.favoriteAlbums.length : 0;
        final historyCount =
            libState is LibraryLoaded ? libState.history.length : 0;
        final latestTrack = (libState is LibraryLoaded &&
                libState.history.isNotEmpty)
            ? libState.history.first.track
            : null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Capsules & Temps Forts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/activity-capsules'),
                    child: Text(
                      'Tout voir ›',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildCleanSettingsRow(
                icon: Icons.auto_stories_outlined,
                title: 'Journal & Fil d’écoute',
                subtitle: latestTrack != null
                    ? 'Dernier : ${latestTrack.title} · $historyCount titres récents'
                    : 'Vos écoutes récentes classées par passage',
                onTap: () => context.push('/activity-capsules'),
              ),
              _subtleDivider(),
              _buildCleanSettingsRow(
                icon: Icons.album_outlined,
                title: 'Albums favoris',
                subtitle: favAlbumsCount > 0
                    ? '$favAlbumsCount album${favAlbumsCount > 1 ? 's' : ''} sauvegardé${favAlbumsCount > 1 ? 's' : ''}'
                    : 'Retrouvez vos albums aimés en un geste',
                onTap: () => context.push('/favorites/albums'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 196 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Préférences',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: StorageService.playerStyleNotifier,
            builder: (context, style, _) {
              final String styleLabel = style == 'default'
                  ? 'Classique Immersif'
                  : 'Signature Sonoritiz (Par défaut)';
              return _buildCleanSettingsRow(
                icon: Icons.waves_rounded,
                title: 'Apparence du lecteur',
                subtitle: styleLabel,
                onTap: () => _showPlayerStyleBottomSheet(context),
              );
            },
          ),
          _subtleDivider(),
          _buildCleanSettingsRow(
            icon: Icons.graphic_eq_rounded,
            title: 'Audio & Égaliseur',
            subtitle: 'Qualité de flux, égaliseur et paroles',
            onTap: () => context.push('/audio-settings'),
          ),
          _subtleDivider(),
          _buildCleanSettingsRow(
            icon: Icons.folder_open_rounded,
            title: 'Stockage & Hors-ligne',
            subtitle: 'Téléchargements et cache audio',
            onTap: () => context.push('/storage-settings'),
          ),
          _subtleDivider(),
          _buildCleanSettingsRow(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: _pushNotifications ? 'Activées' : 'Désactivées',
            trailing: Switch(
              value: _pushNotifications,
              onChanged: (val) async {
                await _storage.savePushNotificationsEnabled(val);
                setState(() => _pushNotifications = val);
              },
              activeThumbColor: AppColors.primary,
            ),
            onTap: () async {
              final next = !_pushNotifications;
              await _storage.savePushNotificationsEnabled(next);
              setState(() => _pushNotifications = next);
            },
          ),
          _subtleDivider(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _logout,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Se déconnecter',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Text(
                'Sonoritiz v2.4',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCleanSettingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.75),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }

  Widget _subtleDivider() {
    return Divider(
      height: 1,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }

  Widget _avatarFallback(double size, {String? text}) {
    final display = text ?? (_username.isNotEmpty ? _username[0].toUpperCase() : '?');
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF1C1C22),
      alignment: Alignment.center,
      child: Text(
        display,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _coverFallback(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1C1C22),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white38,
      ),
    );
  }
}
