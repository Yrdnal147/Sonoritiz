import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonoritiz/core/storage/storage_service.dart';
import 'package:sonoritiz/core/theme/app_colors.dart';
import 'package:sonoritiz/core/widgets/sonoritiz_brand_logo.dart';
import 'package:sonoritiz/features/home/domain/recommendation_engine.dart';
import 'package:sonoritiz/features/onboarding/presentation/onboarding_screen.dart';
import 'package:sonoritiz/features/onboarding/presentation/welcome_screen.dart';
import 'package:sonoritiz/features/player/data/models/track_model.dart';
import 'package:sonoritiz/features/search/presentation/widgets/sonoritiz_moods_widget.dart';
import 'package:sonoritiz/features/splash/presentation/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final Map<String, String> secureStore = {};

  TrackModel makeTrack(String id, String title, String artist) => TrackModel(
        id: id,
        title: title,
        artistName: artist,
        durationSeconds: 210,
        audioUrl: 'https://example.com/$id.mp3',
      );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sonoritiz_unit_');
    Hive.init(tempDir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments is Map) ? call.arguments as Map : const {};
        final key = args['key']?.toString();
        if (call.method == 'write' && key != null) {
          secureStore[key] = args['value']?.toString() ?? '';
          return null;
        }
        if (call.method == 'read' && key != null) {
          return secureStore[key];
        }
        if (call.method == 'delete' && key != null) {
          secureStore.remove(key);
          return null;
        }
        return null;
      },
    );
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Per-account strict isolation', () {
    test(
        'separates favorites, searches, plays, superlikes, albums, and bio across accounts while preserving on relogin',
        () async {
      secureStore.clear();
      SharedPreferences.setMockInitialValues({});
      StorageService.onFavoriteArtistsSaved = null;
      final storage = StorageService();
      await storage.init();

      // 1. Account A (Alice - classical & chanson listener)
      await storage.saveTokens(accessToken: 'tok_a', refreshToken: 'ref_a');
      await storage.saveUserInfo(
        username: 'Alice',
        email: 'alice@sonoritiz.com',
        isNewAccount: true,
      );
      await storage.saveFavoriteArtists(['Charles Aznavour', 'Frédéric Chopin']);
      await storage.setOnboardingSeenFor('alice@sonoritiz.com', true);
      await storage.addSearchQuery('La Bohème');
      await storage.saveUserBio('Amoureuse du piano classique');
      await storage.saveFavoriteAlbumsRaw([
        {'id': 'alb_1', 'title': 'Hier encore', 'artistName': 'Charles Aznavour'},
      ]);
      await storage.saveSuperlikesRaw([
        {
          'id': 'trk_a1',
          'title': 'Nocturne Op.9',
          'artist_name': 'Frédéric Chopin',
          'cover_url': '',
          'duration_seconds': 240,
          'audio_url': 'https://example.com/a1.mp3',
        }
      ]);
      await storage.recordLifetimeTrackPlay({
        'id': 'trk_a1',
        'title': 'Nocturne Op.9',
        'artist_name': 'Frédéric Chopin',
        'cover_url': '',
        'duration_seconds': 240,
        'audio_url': 'https://example.com/a1.mp3',
      });

      expect(storage.getFavoriteArtists(), ['Charles Aznavour', 'Frédéric Chopin']);
      expect(storage.getSearchHistory(), ['La Bohème']);
      expect(storage.getSuperlikesRaw().length, 1);
      expect(storage.getUserSearchedArtistsRaw(), isEmpty);
      await storage.recordSearchedArtist({'id': '892', 'name': 'Charles Aznavour'});
      expect(storage.getUserSearchedArtistsRaw().length, 1);

      // 2. Logout & login as brand new Account B (Bob)
      await storage.clearSession();
      expect(storage.accountScope, 'guest');
      expect(storage.getFavoriteArtists(), isEmpty);
      expect(storage.getSearchHistory(), isEmpty);
      expect(storage.getUserSearchedArtistsRaw(), isEmpty);

      await storage.saveTokens(accessToken: 'tok_b', refreshToken: 'ref_b');
      await storage.saveUserInfo(
        username: 'Bob',
        email: 'bob@sonoritiz.com',
        isNewAccount: true,
      );

      expect(storage.hasCompletedArtistOnboarding, isFalse);
      expect(storage.getFavoriteArtists(), isEmpty);
      expect(storage.getSearchHistory(), isEmpty);
      expect(storage.getUserSearchedArtistsRaw(), isEmpty);
      expect(storage.getSuperlikesRaw(), isEmpty);
      expect(storage.getFavoriteAlbumsRaw(), isEmpty);
      expect(storage.getLifetimeTrackPlaysRaw(), isEmpty);
      expect(storage.userBio, 'Passionné de musique sur Sonoritiz');

      // 3. Alice logs back in -> her data was preserved!
      await storage.clearSession();
      await storage.saveTokens(accessToken: 'tok_a2', refreshToken: 'ref_a2');
      await storage.saveUserInfo(
        username: 'Alice',
        email: 'alice@sonoritiz.com',
        isNewAccount: false,
      );

      expect(storage.hasCompletedArtistOnboarding, isTrue);
      expect(storage.getFavoriteArtists(), ['Charles Aznavour', 'Frédéric Chopin']);
      expect(storage.getSearchHistory(), ['La Bohème']);
      expect(storage.getUserSearchedArtistsRaw().length, 1);
      expect(storage.getSuperlikesRaw().length, 1);
      expect(storage.getFavoriteAlbumsRaw().length, 1);
      expect(storage.getLifetimeTrackPlaysRaw().length, 1);
      expect(storage.userBio, 'Amoureuse du piano classique');
    });

    test('returning existing user never sees onboarding slides again', () async {
      secureStore.clear();
      SharedPreferences.setMockInitialValues({
        'username': 'LegacyUser',
        'favorite_artists': ['Édith Piaf'],
      });
      final storage = StorageService();
      await storage.init();

      expect(storage.hasSeenAppOnboarding, isTrue);
    });
  });

  group('Hybrid Recommendation Engine & Affinity Gate', () {
    test('blocks Afrobeats & Drill injection for Classical/Chanson listener profile', () {
      final profile = RecommendationEngine.buildProfile(
        selectedArtists: [
          'Charles Aznavour',
          'Édith Piaf',
          'Frédéric Chopin',
          'Ludovico Einaudi',
        ],
        superlikedTracks: const [],
        favoriteTracks: const [],
        favoriteAlbumArtists: const [],
        recentLocalEntries: const [],
        historyTracks: const [],
        searchedArtists: const [],
      );

      expect(profile.hasAfroAffinity, isFalse);
      expect(profile.hasHipHopAffinity, isFalse);

      final candidates = [
        makeTrack('1', 'Last Last', 'Burna Boy'),
        makeTrack('2', 'Unavailable', 'Davido'),
        makeTrack('3', 'Die (Drill)', 'Gazo Drill'),
        makeTrack('4', 'La Bohème', 'Charles Aznavour'),
        makeTrack('5', 'Nocturne Op.9', 'Frédéric Chopin'),
        makeTrack('6', 'La Vie en Rose', 'Édith Piaf'),
        makeTrack('7', 'My Way', 'Frank Sinatra'),
      ];

      final ranked = RecommendationEngine.rankTracksForProfile(
        candidates,
        profile,
        limit: 10,
        strictGate: true,
      );

      final artistNames = ranked.map((t) => t.artistName).toList();
      expect(
        artistNames,
        containsAll(['Charles Aznavour', 'Frédéric Chopin', 'Édith Piaf']),
      );
      expect(artistNames, isNot(contains('Burna Boy')));
      expect(artistNames, isNot(contains('Davido')));
      expect(artistNames, isNot(contains('Gazo Drill')));
    });

    test('enables Afro affinity and surfaces Afro queries for Afro profile', () {
      final afroProfile = RecommendationEngine.buildProfile(
        selectedArtists: ['Burna Boy', 'Wizkid', 'Rema'],
        superlikedTracks: const [],
        favoriteTracks: const [],
        favoriteAlbumArtists: const [],
        recentLocalEntries: const [],
        historyTracks: const [],
        searchedArtists: const [],
      );

      expect(afroProfile.hasAfroAffinity, isTrue);
      final queries = RecommendationEngine.buildEmotionQueries(
        selectedEmotions: ['Joie', 'L’amour', 'Espoir'],
        profile: afroProfile,
      );
      expect(queries, isNotEmpty);
    });
  });

  group('Sonoritiz Moods floating bubbles & vector logos', () {
    testWidgets(
        'selecting 3 floating emotion bubbles turns them orange with black text and renders playlist directly',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakePlaylist = List.generate(
        12,
        (i) => makeTrack('mood_$i', 'Titre Émotion $i', 'Artiste $i'),
      );

      List<String>? requestedEmotions;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SingleChildScrollView(
              child: SonoritizMoodsWidget(
                showFullScreenButton: false,
                playlistGenerator: (emotions) async {
                  requestedEmotions = emotions;
                  return fakePlaylist;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      for (final spec in RecommendationEngine.moodEmotions) {
        expect(find.text(spec.label), findsOneWidget);
      }

      await tester.tap(find.byKey(const ValueKey('mood_bubble_joie')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('mood_bubble_nostalgie')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('mood_bubble_espoir')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(requestedEmotions, ['Joie', 'Nostalgie', 'Espoir']);
      expect(find.text('12 titres sélectionnés selon vos goûts'), findsOneWidget);
      expect(find.text('Titre Émotion 0'), findsOneWidget);
      expect(find.text('Tout lire'), findsOneWidget);

      final selectedText = tester.widget<Text>(find.text('Joie'));
      expect(selectedText.style?.color, Colors.black);

      final bubbleContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('mood_bubble_joie')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final deco = bubbleContainer.decoration as BoxDecoration;
      expect(deco.color, AppColors.primary);
    });

    testWidgets('vector logos and 4-color GoogleLogoIcon paint cleanly without errors',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Column(
              children: [
                SonoritizVectorLogo(size: 80, variant: SonoritizLogoVariant.standard),
                SonoritizVectorLogo(size: 40, variant: SonoritizLogoVariant.allWhite),
                SonoritizVectorLogo(
                  size: 40,
                  variant: SonoritizLogoVariant.orangeBecarreWhiteCircles,
                ),
                GoogleLogoIcon(size: 24),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('SplashScreen routes fresh install to /onboarding', (tester) async {
      secureStore.clear();
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(
            path: '/splash',
            builder: (_, __) => SplashScreen(
              storageService: storage,
              splashDuration: const Duration(milliseconds: 40),
              enableAudio: false,
            ),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const Scaffold(body: Text('ONBOARDING_SCREEN')),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const Scaffold(body: Text('LOGIN_SCREEN')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ONBOARDING_SCREEN'), findsOneWidget);
    });

    testWidgets(
        'OnboardingScreen advances 3 slides to WelcomeScreen ("Évadez-vous sur Sonoritiz")',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      secureStore.clear();
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/welcome',
            builder: (_, __) => const WelcomeScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const Scaffold(body: Text('LOGIN')),
          ),
          GoRoute(
            path: '/register',
            builder: (_, __) => const Scaffold(body: Text('REGISTER')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Passer'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Commencer'), findsOneWidget);
      await tester.tap(find.text('Commencer'));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Évadez-vous\nsur Sonoritiz'), findsOneWidget);
      expect(find.text("S'inscrire"), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(storage.hasSeenAppOnboarding, isTrue);
    });
  });
}
