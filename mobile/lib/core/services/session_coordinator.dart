import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/discovery/presentation/cubit/discovery_cubit.dart';
import '../../features/home/presentation/cubit/home_cubit.dart';
import '../../features/library/presentation/cubit/library_cubit.dart';
import '../../features/library/presentation/cubit/library_ui_cubit.dart';
import '../../features/offline/presentation/cubit/download_cubit.dart';
import '../../features/player/presentation/cubit/player_cubit.dart';
import '../../features/player/presentation/cubit/superlike_cubit.dart';
import '../../features/search/presentation/cubit/search_cubit.dart';
import '../storage/storage_service.dart';
import 'favorite_artists_sync_service.dart';

/// Orchestrates strict per-account isolation across logout, login, and signup.
///
/// Ensures no in-memory state, Hive box, player queue, or cached feed leaks
/// between accounts while preserving each account's local persisted data.
class SessionCoordinator {
  static Future<void> handleLogout(BuildContext context) async {
    try {
      await context.read<PlayerCubit>().resetForLogout();
    } catch (_) {}

    await StorageService().clearSession();

    if (!context.mounted) return;
    _resetInMemoryCubits(context);

    try {
      await context.read<DownloadCubit>().resetSessionState();
    } catch (_) {}
  }

  /// Hydrates the newly signed-in / registered user's scoped data and returns
  /// the next route (`/onboarding_artists` for new accounts without chosen
  /// artists, `/home` otherwise).
  static Future<String> handleAuthenticatedUser(
    BuildContext context, {
    required String username,
    required String email,
    bool isNewAccount = false,
    List<dynamic>? serverFavoriteArtists,
  }) async {
    final storage = StorageService();
    await storage.saveUserInfo(
      username: username,
      email: email,
      isNewAccount: isNewAccount,
    );

    if (isNewAccount) {
      await storage.clearWeeklyPlaylistsCache();
    }

    await FavoriteArtistsSyncService().syncAfterAuth(
      serverArtists: serverFavoriteArtists,
    );

    final bool needsArtistOnboarding =
        isNewAccount || !storage.hasCompletedArtistOnboarding;

    if (!context.mounted) {
      return needsArtistOnboarding ? '/onboarding_artists' : '/home';
    }

    _resetInMemoryCubits(context);

    try {
      await context.read<DownloadCubit>().reloadForCurrentUser();
    } catch (_) {}
    if (!context.mounted) {
      return needsArtistOnboarding ? '/onboarding_artists' : '/home';
    }

    try {
      context.read<SuperlikeCubit>().reloadForCurrentUser();
    } catch (_) {}
    try {
      context.read<LibraryUiCubit>().reloadForCurrentUser();
    } catch (_) {}
    try {
      context.read<SearchCubit>().resetSessionState();
    } catch (_) {}
    try {
      unawaited(context.read<LibraryCubit>().loadLibraryData());
    } catch (_) {}
    try {
      unawaited(context.read<HomeCubit>().loadHomeData(forceRefresh: true));
    } catch (_) {}
    try {
      context.read<DiscoveryCubit>().resetSessionState();
    } catch (_) {}

    return needsArtistOnboarding ? '/onboarding_artists' : '/home';
  }

  static void _resetInMemoryCubits(BuildContext context) {
    try {
      context.read<HomeCubit>().resetSessionState();
    } catch (_) {}
    try {
      context.read<LibraryCubit>().resetSessionState();
    } catch (_) {}
    try {
      context.read<SuperlikeCubit>().resetSessionState();
    } catch (_) {}
    try {
      context.read<SearchCubit>().resetSessionState();
    } catch (_) {}
    try {
      context.read<DiscoveryCubit>().resetSessionState();
    } catch (_) {}
    try {
      context.read<LibraryUiCubit>().reloadForCurrentUser();
    } catch (_) {}
  }
}
