import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/storage/storage_service.dart';
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

  runApp(SonoritizApp(
    storageService: storageService,
    audioHandler: audioHandler,
    offlineRepository: offlineRepository,
  ));
}

class SonoritizApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final router = AppRouter.createRouter(storageService);

    return MultiBlocProvider(
      providers: [
        BlocProvider<PlayerCubit>(
          create: (_) => PlayerCubit(audioHandler: audioHandler),
        ),
        BlocProvider<LibraryCubit>(
          create: (_) => LibraryCubit(
            repository: LibraryRepository(apiClient: ApiClient(storageService: storageService)),
          )..loadLibraryData(),
        ),
        BlocProvider<LibraryUiCubit>(
          create: (_) => LibraryUiCubit(storageService: storageService),
        ),
        BlocProvider<DownloadCubit>(
          create: (_) => DownloadCubit(repository: offlineRepository)..loadDownloads(),
        ),
        BlocProvider<SearchCubit>(
          create: (_) => SearchCubit(
            repository: CatalogRepository(apiClient: ApiClient(storageService: storageService)),
            storageService: storageService,
          ),
        ),
      ],
      child: MaterialApp.router(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    );
  }
}

