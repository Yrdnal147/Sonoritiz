import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../storage/storage_service.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/navigation/presentation/main_shell_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/connect/presentation/connect_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/player/presentation/screens/fullscreen_player_screen.dart';
import '../../features/home/presentation/screens/nouveautes_screen.dart';
import '../../features/home/presentation/screens/select_artists_screen.dart';
import '../../features/home/presentation/screens/artist_playlist_screen.dart';
import '../../features/artist/presentation/screens/artist_detail_screen.dart';
import '../../features/quiz/presentation/quiz_screen.dart';
import '../../features/podcast/presentation/podcast_screen.dart';
import '../../features/podcast/presentation/podcast_player_screen.dart';
import '../../features/discovery/presentation/screens/discovery_feed_screen.dart';
import '../../features/player/data/models/track_model.dart';
class AppRouter {
  static GoRouter createRouter(StorageService storageService) {
    return GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => SplashScreen(storageService: storageService),
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
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainShellScreen(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) => const SearchScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/library',
                  builder: (context, state) => const LibraryScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/connect',
                  builder: (context, state) => const ConnectScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/fullscreen',
          builder: (context, state) => const FullscreenPlayerScreen(),
        ),
        GoRoute(
          path: '/trends',
          builder: (context, state) => const NouveautesScreen(),
        ),
        GoRoute(
          path: '/select-artists',
          builder: (context, state) => const SelectArtistsScreen(),
        ),
        GoRoute(
          path: '/artist-playlist',
          builder: (context, state) {
            final artistName = state.extra as String?;
            return ArtistPlaylistScreen(artistName: artistName ?? 'Artiste');
          },
        ),
        GoRoute(
          path: '/artist',
          builder: (context, state) {
            final artistInfo = state.extra as Map<String, String>?;
            return ArtistDetailScreen(artistInfo: artistInfo ?? {});
          },
        ),
        GoRoute(
          path: '/quiz',
          builder: (context, state) => const QuizScreen(),
        ),
        GoRoute(
          path: '/podcasts',
          builder: (context, state) => const PodcastScreen(),
        ),
        GoRoute(
          path: '/podcast_player',
          builder: (context, state) {
            final track = state.extra as TrackModel;
            return PodcastPlayerScreen(track: track);
          },
        ),
        GoRoute(
          path: '/discovery/:type',
          builder: (context, state) {
            final type = state.pathParameters['type'] ?? 'audio';
            return DiscoveryFeedScreen(feedType: type);
          },
        ),
      ],
    );
  }
}
