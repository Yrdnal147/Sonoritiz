import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/storage/storage_service.dart';
import 'core/audio/audio_handler.dart';
import 'core/router/app_router.dart';
import 'features/player/data/models/track_model.dart';
import 'features/player/presentation/cubit/player_cubit.dart';
import 'core/network/api_client.dart';
import 'features/library/data/repositories/library_repository.dart';
import 'features/library/presentation/cubit/library_cubit.dart';
import 'features/library/presentation/cubit/library_ui_cubit.dart';
import 'features/offline/data/repositories/offline_repository.dart';
import 'features/offline/presentation/cubit/download_cubit.dart';
import 'features/search/presentation/cubit/search_cubit.dart';
import 'features/home/data/repositories/catalog_repository.dart';
import 'features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:home_widget/home_widget.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri != null && uri.scheme == 'sonoritiz') {
    // Initialisation rapide pour se connecter au service audio existant
    final offlineRepository = OfflineRepository();
    await offlineRepository.init();
    final audioHandler = await initAudioHandler(offlineRepository: offlineRepository);

    if (uri.host == 'playpause') {
      if (audioHandler.player.playing) {
        await audioHandler.pause();
      } else {
        await audioHandler.play();
      }
    } else if (uri.host == 'next') {
      await audioHandler.skipToNext();
    } else if (uri.host == 'prev') {
      await audioHandler.skipToPrevious();
    } else if (uri.host == 'favorite') {
      try {
        final currentTrack = audioHandler.mediaItem.value;
        if (currentTrack != null) {
          final storage = StorageService();
          await storage.init();
          final libraryRepo = LibraryRepository(apiClient: ApiClient(storageService: storage));
          final isFav = await libraryRepo.isFavorite(currentTrack.id);
          if (isFav) {
             await libraryRepo.removeFavorite(currentTrack.id);
             await HomeWidget.saveWidgetData<bool>('isFavorite', false);
          } else {
             await libraryRepo.addFavorite(TrackModel.fromJson(currentTrack.extras!));
             await HomeWidget.saveWidgetData<bool>('isFavorite', true);
          }
          await HomeWidget.updateWidget(androidName: 'NowPlayingWidgetProvider');
          await HomeWidget.updateWidget(androidName: 'PlaylistWidgetProvider');
        }
      } catch (e) {
        // Ignorer l'erreur
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local Hive storage
  await Hive.initFlutter();

  // Initialize Storage Service (SharedPreferences)
  final storageService = StorageService();
  await storageService.init();

  // Initialize Offline Repository FIRST
  final offlineRepository = OfflineRepository();
  await offlineRepository.init();

  // Initialize Native Audio Service & Handler (inject offlineRepo)
  final audioHandler = await initAudioHandler(offlineRepository: offlineRepository);

  // Register home widget callback
  await HomeWidget.registerBackgroundCallback(backgroundCallback);

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

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(widget.storageService);
    
    HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri?.scheme == 'sonoritiz' && uri?.host == 'playlists') {
        _router.go('/library');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryRepository = LibraryRepository(apiClient: ApiClient(storageService: widget.storageService));

    return MultiBlocProvider(
      providers: [
        BlocProvider<PlayerCubit>(
          create: (_) => PlayerCubit(
            audioHandler: widget.audioHandler,
            libraryRepository: libraryRepository,
          ),
        ),
        BlocProvider<LibraryCubit>(
          create: (_) => LibraryCubit(
            repository: libraryRepository,
          )..loadLibraryData(),
        ),
        BlocProvider<LibraryUiCubit>(
          create: (_) => LibraryUiCubit(storageService: widget.storageService),
        ),
        BlocProvider<DownloadCubit>(
          create: (_) => DownloadCubit(repository: widget.offlineRepository)..loadDownloads(),
        ),
        BlocProvider<SearchCubit>(
          create: (_) => SearchCubit(
            repository: CatalogRepository(apiClient: ApiClient(storageService: widget.storageService)),
            storageService: widget.storageService,
          ),
        ),
        BlocProvider<DiscoveryCubit>(
          create: (_) => DiscoveryCubit(
            storageService: widget.storageService,
            catalogRepository: CatalogRepository(apiClient: ApiClient(storageService: widget.storageService)),
          ),
        ),
      ],
      child: MaterialApp.router(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routeInformationProvider: _router.routeInformationProvider,
        routeInformationParser: _router.routeInformationParser,
        routerDelegate: _router.routerDelegate,
      ),
    );
  }
}
