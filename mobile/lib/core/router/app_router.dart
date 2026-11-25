import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../storage/storage_service.dart';
import '../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../core/widgets/sonoritiz_page_title.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/onboarding/presentation/onboarding_artists_screen.dart';
import '../../features/search/presentation/moods_screen.dart';
import '../../features/navigation/presentation/main_shell_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/connect/presentation/connect_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/home/presentation/cubit/home_cubit.dart';
import '../../features/home/presentation/screens/nouveautes_screen.dart';
import '../../features/home/presentation/screens/new_releases_screen.dart';
import '../../features/home/presentation/screens/select_artists_screen.dart';
import '../../features/home/presentation/screens/artist_playlist_screen.dart';
import '../../features/home/presentation/screens/category_list_screen.dart';
import '../../features/artist/presentation/screens/artist_detail_screen.dart';
import '../../features/artist/presentation/screens/album_detail_screen.dart';
import '../../features/quiz/presentation/quiz_screen.dart';
import '../../features/podcast/presentation/podcast_screen.dart';
import '../../features/podcast/presentation/podcast_player_screen.dart';
import '../../features/player/data/models/track_model.dart';
import '../../features/player/presentation/screens/fullscreen_player_screen.dart';
import '../../features/discovery/presentation/screens/discovery_feed_screen.dart';
import '../../features/library/data/repositories/library_repository.dart';
import '../../features/library/presentation/cubit/library_cubit.dart';
import '../../features/library/presentation/cubit/library_state.dart';
import '../../features/library/presentation/favorites_screen.dart';
import '../../features/library/presentation/favorite_albums_screen.dart';
import '../../features/library/presentation/liked_tracks_screen.dart';
import '../../features/library/presentation/superliked_tracks_screen.dart';
import '../../features/library/presentation/playlists_list_screen.dart';
import '../../features/library/presentation/local_audio_screen.dart';
import '../../features/library/presentation/playlist_detail_screen.dart';
import '../../features/profile/presentation/stats_screen.dart';
import '../../features/profile/presentation/followed_artists_screen.dart';
import '../../features/profile/presentation/audio_settings_screen.dart';
import '../../features/profile/presentation/storage_settings_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/sound_passport_screen.dart';
import '../../features/profile/presentation/activity_capsules_screen.dart';

class AppRouter {
  static GoRouter createRouter(StorageService storageService) {
    return GoRouter(
      initialLocation: '/splash',
      routes: [
        // =====================================================================
        // 1. FLUX D'AUTHENTIFICATION & ONBOARDING (Sans barre de navigation)
        // =====================================================================
        GoRoute(
          path: '/splash',
          builder: (context, state) =>
              SplashScreen(storageService: storageService),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/onboarding_artists',
          builder: (context, state) => const OnboardingArtistScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) {
            final token = state.uri.queryParameters['token'] ?? '';
            return ResetPasswordScreen(token: token);
          },
        ),

        // =====================================================================
        // 2. SHELL PERSISTANT PRINCIPAL (AVEC Barre + Mini-Lecteur)
        // Englobe les 5 onglets racines ET toutes les sous-pages de contenu
        // =====================================================================
        ShellRoute(
          builder: (context, state, child) {
            return MainShellScreen(child: child);
          },
          routes: [
            // --- Les 5 Onglets Racines ---
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
            GoRoute(
              path: '/moods',
              builder: (context, state) => const MoodsScreen(),
            ),
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
            ),
            GoRoute(
              path: '/connect',
              builder: (context, state) => const ConnectScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),

            // --- Catalogue & Découverte ---
            GoRoute(
              path: '/category',
              builder: (context, state) => CategoryListScreen(
                  category: state.extra as Map<String, dynamic>),
            ),
            GoRoute(
              path: '/artist',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>? ?? {};
                return ArtistDetailScreen(
                  artistInfo:
                      extra.map((key, value) => MapEntry(key, value.toString())),
                );
              },
            ),
            GoRoute(
              path: '/album',
              builder: (context, state) {
                final extra = state.extra;
                Map<String, dynamic> albumData = {};
                if (extra is Map<String, dynamic>) {
                  albumData = extra;
                } else if (extra is Map) {
                  albumData = Map<String, dynamic>.from(extra);
                } else if (extra is int) {
                  albumData = {'id': extra};
                } else if (extra is String) {
                  albumData = {'id': int.tryParse(extra) ?? 0};
                }
                return AlbumDetailScreen(albumData: albumData);
              },
            ),
            GoRoute(
              path: '/trends',
              builder: (context, state) => const NouveautesScreen(),
            ),
            GoRoute(
              path: '/new-releases',
              builder: (context, state) => const NewReleasesScreen(),
            ),
            GoRoute(
              path: '/artist-playlist',
              builder: (context, state) {
                final artistName = state.extra as String?;
                return ArtistPlaylistScreen(artistName: artistName ?? 'Artiste');
              },
            ),
            GoRoute(
              path: '/select-artists',
              builder: (context, state) {
                final homeCubit = state.extra as HomeCubit?;
                if (homeCubit != null) {
                  return BlocProvider.value(
                    value: homeCubit,
                    child: const SelectArtistsScreen(),
                  );
                }
                return const SelectArtistsScreen();
              },
            ),
            GoRoute(
              path: '/select_artists',
              builder: (context, state) {
                final homeCubit = state.extra as HomeCubit?;
                if (homeCubit != null) {
                  return BlocProvider.value(
                    value: homeCubit,
                    child: const SelectArtistsScreen(),
                  );
                }
                return const SelectArtistsScreen();
              },
            ),
            GoRoute(
              path: '/podcasts',
              builder: (context, state) => const PodcastScreen(),
            ),

            // --- Bibliothèque & Playlists ---
            GoRoute(
              path: '/favorites',
              builder: (context, state) =>
                  BlocBuilder<LibraryCubit, LibraryState>(
                builder: (context, libState) {
                  final favs = libState is LibraryLoaded
                      ? libState.favorites
                      : <TrackModel>[];
                  final heroCover = favs.isNotEmpty ? favs.first.coverUrl : '';
                  return Scaffold(
                    backgroundColor: Colors.black,
                    body: SonoritizCoverAtmosphere(
                      coverUrl: heroCover,
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppBar(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              leading: IconButton(
                                icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 20),
                                onPressed: () => context.pop(),
                              ),
                              title: const SonoritizPageTitle(
                                title: 'Favoris',
                                fontSize: 22,
                              ),
                            ),
                            Expanded(child: FavoritesScreen(favorites: favs)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            GoRoute(
              path: '/favorites/albums',
              builder: (context, state) => const FavoriteAlbumsScreen(),
            ),
            GoRoute(
              path: '/favorites/tracks',
              builder: (context, state) => const LikedTracksScreen(),
            ),
            GoRoute(
              path: '/favorites/superlikes',
              builder: (context, state) => const SuperlikedTracksScreen(),
            ),
            GoRoute(
              path: '/playlists_list',
              builder: (context, state) =>
                  BlocBuilder<LibraryCubit, LibraryState>(
                builder: (context, libState) {
                  final playlists = libState is LibraryLoaded
                      ? libState.playlists
                      : <PlaylistModel>[];
                  final heroCover = playlists.isNotEmpty
                      ? (playlists.first.tracks.isNotEmpty
                          ? playlists.first.tracks.first.coverUrl
                          : playlists.first.coverUrl)
                      : '';
                  return Scaffold(
                    backgroundColor: Colors.black,
                    body: SonoritizCoverAtmosphere(
                      coverUrl: heroCover,
                      child: SafeArea(
                        child: Column(
                          children: [
                            AppBar(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              leading: IconButton(
                                icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 20),
                                onPressed: () => context.pop(),
                              ),
                              title: const SonoritizPageTitle(
                                title: 'Playlists',
                                fontSize: 22,
                              ),
                            ),
                            Expanded(
                                child:
                                    PlaylistsListScreen(playlists: playlists)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            GoRoute(
              path: '/playlists',
              builder: (context, state) =>
                  BlocBuilder<LibraryCubit, LibraryState>(
                builder: (context, libState) {
                  final playlists = libState is LibraryLoaded
                      ? libState.playlists
                      : <PlaylistModel>[];
                  final heroCover = playlists.isNotEmpty
                      ? (playlists.first.tracks.isNotEmpty
                          ? playlists.first.tracks.first.coverUrl
                          : playlists.first.coverUrl)
                      : '';
                  return Scaffold(
                    backgroundColor: Colors.black,
                    body: SonoritizCoverAtmosphere(
                      coverUrl: heroCover,
                      child: SafeArea(
                        child: Column(
                          children: [
                            AppBar(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              leading: IconButton(
                                icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 20),
                                onPressed: () => context.pop(),
                              ),
                              title: const SonoritizPageTitle(
                                title: 'Playlists',
                                fontSize: 22,
                              ),
                            ),
                            Expanded(
                                child:
                                    PlaylistsListScreen(playlists: playlists)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            GoRoute(
              path: '/playlist',
              builder: (context, state) {
                final playlist = state.extra as PlaylistModel;
                return PlaylistDetailScreen(playlist: playlist);
              },
            ),
            GoRoute(
              path: '/local_audio',
              builder: (context, state) => Scaffold(
                backgroundColor: Colors.black,
                body: SonoritizCoverAtmosphere(
                  coverUrl: '',
                  child: SafeArea(
                    child: Column(
                      children: [
                        AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          leading: IconButton(
                            icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20),
                            onPressed: () => context.pop(),
                          ),
                          title: const SonoritizPageTitle(
                            title: 'Fichiers locaux',
                            fontSize: 22,
                          ),
                        ),
                        Expanded(
                            child: LocalAudioScreen(
                                storageService: storageService)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/local-audio',
              builder: (context, state) => Scaffold(
                backgroundColor: Colors.black,
                body: SonoritizCoverAtmosphere(
                  coverUrl: '',
                  child: SafeArea(
                    child: Column(
                      children: [
                        AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          leading: IconButton(
                            icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20),
                            onPressed: () => context.pop(),
                          ),
                          title: const SonoritizPageTitle(
                            title: 'Fichiers locaux',
                            fontSize: 22,
                          ),
                        ),
                        Expanded(
                            child: LocalAudioScreen(
                                storageService: storageService)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // --- Profil & Réglages ---
            GoRoute(
              path: '/stats',
              builder: (context, state) => const StatsScreen(),
            ),
            GoRoute(
              path: '/followed-artists',
              builder: (context, state) => const FollowedArtistsScreen(),
            ),
            GoRoute(
              path: '/followed_artists',
              builder: (context, state) => const FollowedArtistsScreen(),
            ),
            GoRoute(
              path: '/audio-settings',
              builder: (context, state) => const AudioSettingsScreen(),
            ),
            GoRoute(
              path: '/storage-settings',
              builder: (context, state) => const StorageSettingsScreen(),
            ),
            GoRoute(
              path: '/edit-profile',
              builder: (context, state) => const EditProfileScreen(),
            ),
            GoRoute(
              path: '/sound-passport',
              builder: (context, state) => const SoundPassportScreen(),
            ),
            GoRoute(
              path: '/activity-capsules',
              builder: (context, state) => const ActivityCapsulesScreen(),
            ),
          ],
        ),

        // =====================================================================
        // 3. FLUX IMMERSIFS PLEIN ÉCRAN (Volontairement SANS barre)
        // =====================================================================
        GoRoute(
          path: '/fullscreen',
          builder: (context, state) => const FullscreenPlayerScreen(),
        ),
        GoRoute(
          path: '/discovery/:type',
          builder: (context, state) {
            final type = state.pathParameters['type'] ?? 'audio';
            final extra = state.extra;
            if (extra is Map<String, dynamic>) {
              final rawTracks = extra['tracks'];
              final List<TrackModel>? customTracks =
                  rawTracks is List<TrackModel>
                      ? rawTracks
                      : (rawTracks is List
                          ? rawTracks.whereType<TrackModel>().toList()
                          : null);
              return DiscoveryFeedScreen(
                feedType: type,
                customTracks: customTracks,
                artistName: extra['artistName'] as String?,
                clipDurationSeconds:
                    (extra['clipDurationSeconds'] as int?) ?? 20,
                focusHighlight: (extra['focusHighlight'] as bool?) ?? false,
              );
            }
            return DiscoveryFeedScreen(feedType: type);
          },
        ),
        GoRoute(
          path: '/podcast_player',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Map<String, dynamic>) {
              final track = extra['track'] as TrackModel;
              final bool initialVideoMode =
                  extra['initialVideoMode'] == true;
              final int posSec =
                  (extra['initialPositionSeconds'] as int?) ?? 0;
              return PodcastPlayerScreen(
                track: track,
                initialVideoMode: initialVideoMode,
                initialPosition:
                    posSec > 0 ? Duration(seconds: posSec) : null,
              );
            }
            final track = extra as TrackModel;
            return PodcastPlayerScreen(track: track);
          },
        ),
        GoRoute(
          path: '/quiz',
          builder: (context, state) => const QuizScreen(),
        ),
      ],
    );
  }
}
