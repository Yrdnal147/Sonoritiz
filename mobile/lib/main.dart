import 'dart:async';
import 'dart:ui' show PlatformDispatcher, PointerDeviceKind;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/storage/storage_service.dart';
import 'core/services/favorite_artists_sync_service.dart';
import 'core/audio/audio_handler.dart';
import 'core/router/app_router.dart';
import 'features/player/presentation/cubit/player_cubit.dart';
import 'core/network/api_client.dart';
import 'features/library/data/repositories/library_repository.dart';
import 'features/library/presentation/cubit/library_cubit.dart';
import 'features/library/presentation/cubit/library_ui_cubit.dart';
import 'features/offline/data/repositories/offline_repository.dart';
import 'features/offline/presentation/cubit/download_cubit.dart';
import 'features/search/presentation/cubit/search_cubit.dart';
import 'features/home/data/repositories/catalog_repository.dart';
import 'features/home/presentation/cubit/home_cubit.dart';
import 'features/discovery/presentation/cubit/discovery_cubit.dart';
import 'features/connect/data/repositories/connect_repository.dart';
import 'features/connect/presentation/cubit/connect_cubit.dart';
import 'features/player/presentation/cubit/superlike_cubit.dart';
import 'package:home_widget/home_widget.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri == null || uri.scheme != 'sonoritiz') return;
  try {
    if (uri.host == 'repeat') {
      final currentRepeat = await HomeWidget.getWidgetData<bool>('isRepeat', defaultValue: false) ?? false;
      final nextRepeat = !currentRepeat;
      await HomeWidget.saveWidgetData<bool>('isRepeat', nextRepeat);
      await HomeWidget.updateWidget(androidName: 'NowPlayingWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'PlaylistWidgetProvider');
    } else if (uri.host == 'favorite') {
      final currentFav = await HomeWidget.getWidgetData<bool>('isFavorite', defaultValue: false) ?? false;
      final nextFav = !currentFav;
      await HomeWidget.saveWidgetData<bool>('isFavorite', nextFav);
      await HomeWidget.updateWidget(androidName: 'NowPlayingWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'PlaylistWidgetProvider');
    
    }
  } catch (e) {
    debugPrint("Erreur backgroundCallback widget: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Filet de sécurité : une erreur asynchrone inattendue (téléchargement, réseau...)
  // est journalisée mais ne doit jamais faire tomber l'application ni la musique.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Erreur non gérée: $error\n$stack');
    return true;
  };

  // Initialize local Hive storage
  await Hive.initFlutter();

  // Initialize Storage Service (SharedPreferences)
  final storageService = StorageService();
  await storageService.init();
  StorageService.onFavoriteArtistsSaved =
      (artists) => FavoriteArtistsSyncService().pushFavoriteArtists(artists);
  StorageService.onSuperlikesSaved =
      (tracks) => FavoriteArtistsSyncService().pushSuperlikes(tracks);
  StorageService.onFavoriteAlbumsSaved =
      (albums) => FavoriteArtistsSyncService().pushFavoriteAlbums(albums);

  // Initialize Offline Repository FIRST
  final offlineRepository = OfflineRepository();
  await offlineRepository.init();

  // Initialize Native Audio Service & Handler (inject offlineRepo)
  final audioHandler = await initAudioHandler(offlineRepository: offlineRepository);

  // Register home widget callback (Android uniquement)
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await HomeWidget.registerBackgroundCallback(backgroundCallback);
    } catch (_) {}
  }

  runApp(SonoritizApp(
    storageService: storageService,
    audioHandler: audioHandler,
    offlineRepository: offlineRepository,
  ));
}

class SonoritizApp extends StatefulWidget {
  final StorageService storageService;
  final SonoritizAudioHandler audioHandler;
  final OfflineRepository offlineRepository;

  const SonoritizApp({
    Key? key,
    required this.storageService,
    required this.audioHandler,
    required this.offlineRepository,
  }) : super(key: key);

  @override
  State<SonoritizApp> createState() => _SonoritizAppState();
}

class _SonoritizAppState extends State<SonoritizApp> {
  late final GoRouter _router;
  late final ApiClient _apiClient;
  late final LibraryRepository _libraryRepository;
  late final CatalogRepository _catalogRepository;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(widget.storageService);
    _apiClient = ApiClient(storageService: widget.storageService);
    _libraryRepository = LibraryRepository(apiClient: _apiClient);
    _catalogRepository = CatalogRepository(apiClient: _apiClient);
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<CatalogRepository>.value(
      value: _catalogRepository,
      child: MultiBlocProvider(
        providers: [
        BlocProvider<PlayerCubit>(
          create: (_) => PlayerCubit(
            audioHandler: widget.audioHandler,
            libraryRepository: _libraryRepository,
          ),
        ),
        BlocProvider<LibraryCubit>(
          create: (_) {
            final cubit = LibraryCubit(repository: _libraryRepository);
            if (widget.storageService.isAuthenticated) {
              cubit.loadLibraryData();
            }
            return cubit;
          },
        ),
        BlocProvider<LibraryUiCubit>(
          create: (_) => LibraryUiCubit(storageService: widget.storageService),
        ),
        BlocProvider<DownloadCubit>(
          create: (_) => DownloadCubit(repository: widget.offlineRepository)..loadDownloads(),
        ),
        BlocProvider<SearchCubit>(
          create: (_) => SearchCubit(
            repository: _catalogRepository,
            storageService: widget.storageService,
          ),
        ),
        BlocProvider<DiscoveryCubit>(
          create: (_) => DiscoveryCubit(
            storageService: widget.storageService,
            catalogRepository: _catalogRepository,
          ),
        ),
        BlocProvider<HomeCubit>(
          create: (_) {
            final cubit = HomeCubit(
              catalogRepository: _catalogRepository,
              libraryRepository: _libraryRepository,
              storageService: widget.storageService,
            );
            if (widget.storageService.isAuthenticated) {
              cubit.loadHomeData();
            }
            return cubit;
          },
        ),
        BlocProvider<SuperlikeCubit>(
          create: (_) => SuperlikeCubit(
            storageService: widget.storageService,
            audioHandler: widget.audioHandler,
          ),
        ),
        BlocProvider<ConnectCubit>(
          create: (ctx) => ConnectCubit(
            storageService: widget.storageService,
            repository: ConnectRepository(apiClient: _apiClient),
            playerCubit: ctx.read<PlayerCubit>(),
          ),
        ),
      ],
      child: _AppLifecycleAndWidgetBridge(
        router: _router,
        child: _DesktopKeyboardPlayerShortcuts(
          child: MaterialApp.router(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            scrollBehavior: const _SonoritizScrollBehavior(),
            routeInformationProvider: _router.routeInformationProvider,
            routeInformationParser: _router.routeInformationParser,
            routerDelegate: _router.routerDelegate,
          ),
        ),
      ),
    ),
    );
  }
}

/// Autorise le glisser-déposer des carrousels horizontaux et PageViews
/// à la souris, au trackpad et au stylet (PC, Web, Tablettes, Samsung DeX).
class _SonoritizScrollBehavior extends MaterialScrollBehavior {
  const _SonoritizScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

/// Raccourcis clavier globaux sur PC / Tablette avec clavier physique
/// (Espace : Play/Pause, Alt+Flèche Droite/Gauche : Suivant/Précédent),
/// automatiquement désactivés lorsqu'un champ de texte a le focus.
class _DesktopKeyboardPlayerShortcuts extends StatelessWidget {
  final Widget child;

  const _DesktopKeyboardPlayerShortcuts({required this.child});

  bool _isTypingInTextField() {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (ctx == null) return false;
    bool insideEditable = false;
    if (ctx.widget is EditableText) return true;
    ctx.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        insideEditable = true;
        return false;
      }
      return true;
    });
    return insideEditable;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: false,
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_isTypingInTextField()) return KeyEventResult.ignored;

        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.mediaPlayPause) {
          context.read<PlayerCubit>().togglePlayPause();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.mediaTrackNext ||
            (HardwareKeyboard.instance.isAltPressed &&
                key == LogicalKeyboardKey.arrowRight)) {
          context.read<PlayerCubit>().playNext();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.mediaTrackPrevious ||
            (HardwareKeyboard.instance.isAltPressed &&
                key == LogicalKeyboardKey.arrowLeft)) {
          context.read<PlayerCubit>().playPrevious();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

class _AppLifecycleAndWidgetBridge extends StatefulWidget {
  final GoRouter router;
  final Widget child;

  const _AppLifecycleAndWidgetBridge({
    required this.router,
    required this.child,
  });

  @override
  State<_AppLifecycleAndWidgetBridge> createState() => _AppLifecycleAndWidgetBridgeState();
}

class _AppLifecycleAndWidgetBridgeState extends State<_AppLifecycleAndWidgetBridge>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
        if (mounted && uri != null) {
          _handleWidgetUri(uri, isInitialLaunch: true);
        }
      }).catchError((_) {});

      _widgetClickSub = HomeWidget.widgetClicked.listen((uri) {
        if (mounted && uri != null) {
          _handleWidgetUri(uri, isInitialLaunch: false);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      if (!StorageService().isAuthenticated) return;
      context.read<PlayerCubit>().syncFromWidgetPreferences().then((_) {
        if (mounted && StorageService().isAuthenticated) {
          context.read<LibraryCubit>().loadLibraryData();
        }
      });
    }
  }

  void _handleWidgetUri(Uri uri, {required bool isInitialLaunch}) {
    if (uri.scheme != 'sonoritiz') return;

    final delay = isInitialLaunch ? const Duration(milliseconds: 600) : Duration.zero;
    Future.delayed(delay, () {
      if (!mounted) return;
      final host = uri.host;
      if (host == 'playlists' || host == 'history') {
        widget.router.go('/library');
      } else if (host == 'artist') {
        final currentTrack = context.read<PlayerCubit>().state.currentTrack;
        if (currentTrack != null && currentTrack.artistName.isNotEmpty) {
          widget.router.push('/artist', extra: {
            'name': currentTrack.artistName,
          });
        }
      } else if (host == 'player' || host == 'lyrics') {
        final currentLocation = widget.router.routerDelegate.currentConfiguration.uri.path;
        final hasTrack = context.read<PlayerCubit>().state.currentTrack != null;
        if (hasTrack) {
          if (currentLocation != '/fullscreen') {
            widget.router.push('/fullscreen');
          }
        } else {
          if (currentLocation == '/splash' || currentLocation.isEmpty) {
            return;
          }
          widget.router.go('/home');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
