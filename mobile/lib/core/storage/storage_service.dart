import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static final ValueNotifier<String> playerStyleNotifier =
      ValueNotifier<String>('vertical');
  static final ValueNotifier<List<String>> favoriteArtistsNotifier =
      ValueNotifier<List<String>>(<String>[]);
  static final ValueNotifier<List<Map<String, dynamic>>> recentPodcastsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>(<Map<String, dynamic>>[]);
  static final ValueNotifier<List<Map<String, dynamic>>>
      connectRecommendationsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>(<Map<String, dynamic>>[]);
  static final ValueNotifier<List<Map<String, dynamic>>>
      downloadedAlbumsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>(<Map<String, dynamic>>[]);

  /// Hooks optionnels enregistrés au démarrage de l'app pour synchroniser les
  /// préférences avec le backend Django sans coupler StorageService aux tests unitaires.
  static Future<void> Function(List<String> artists)? onFavoriteArtistsSaved;
  static Future<void> Function(List<Map<String, dynamic>> tracks)? onSuperlikesSaved;
  static Future<void> Function(List<Map<String, dynamic>> albums)? onFavoriteAlbumsSaved;

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyOnboardingSeen = 'onboarding_seen';
  static const String _keyAppOnboardingDone = 'app_onboarding_completed';
  static const String _keyUsername = 'username';
  static const String _keyEmail = 'email';
  static const String _keySearchHistory = 'search_history';
  static const String _keyViewMode = 'library_view_mode';
  static const String _keySortMode = 'library_sort_mode';
  static const String _keyLocalFiles = 'local_audio_files';
  static const String _keyProfileImagePath = 'profile_image_path';
  static const String _keyFavoriteArtists = 'favorite_artists';
  static const String _keyFreeLyricsMode = 'is_free_lyrics_mode';
  static const String _keySearchedArtists = 'searched_artists_registry';
  static const String _keySuperlikes = 'sonoritiz_superlikes';
  static const String _keyFavoriteAlbums = 'sonoritiz_favorite_albums';
  static const String _keyLifetimePlays = 'lifetime_plays';
  static const String _keyWeeklyPlaylists = 'weekly_curated_playlists_v3';
  static const String _keyWeeklyPlaylistsTs = 'weekly_curated_playlists_ts_v3';
  static const String _keyUserBio = 'user_bio';
  static const String _keyLegacyMigrated = 'migrated_legacy_user_keys_v1';

  late SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // In-memory cache for synchronous access
  String? _cachedAccessToken;
  String? _cachedRefreshToken;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _cachedAccessToken = await _secureStorage.read(key: _keyAccessToken);
    _cachedRefreshToken = await _secureStorage.read(key: _keyRefreshToken);

    if (isAuthenticated && accountScope != 'guest') {
      await _migrateLegacyGlobalKeysIfNeeded();
    }
    refreshAccountNotifiers();
  }

  /// Identifiant unique de cloisonnement par compte (email prioritaire, sinon username).
  String get accountScope {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isNotEmpty) return normalizedEmail;
    final normalizedUsername = username.trim().toLowerCase();
    if (normalizedUsername.isNotEmpty) return normalizedUsername;
    return 'guest';
  }

  /// Slug alphanumérique sûr pour noms de boîtes Hive et sous-dossiers disque.
  String get safeAccountSlug =>
      accountScope.replaceAll(RegExp(r'[^a-z0-9]'), '_');

  String _scopedKey(String base) => '${base}_$accountScope';

  void refreshAccountNotifiers() {
    if (!(_prefsInitialized)) return;
    playerStyleNotifier.value = playerStyle;
    favoriteArtistsNotifier.value = getFavoriteArtists();
    recentPodcastsNotifier.value = getRecentPodcastsRaw();
    connectRecommendationsNotifier.value = getConnectGuestRecommendationsRaw();
    downloadedAlbumsNotifier.value = getDownloadedAlbumsRaw();
  }

  bool get _prefsInitialized {
    try {
      _prefs.containsKey(_keyOnboardingSeen);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _migrateStringListKeyIfMissing(String baseKey) async {
    final scoped = _scopedKey(baseKey);
    if (_prefs.containsKey(scoped)) return;
    final legacy = _prefs.getStringList(baseKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _prefs.setStringList(scoped, legacy);
    }
  }

  Future<void> _migrateStringKeyIfMissing(String baseKey) async {
    final scoped = _scopedKey(baseKey);
    if (_prefs.containsKey(scoped)) return;
    final legacy = _prefs.getString(baseKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _prefs.setString(scoped, legacy);
    }
  }

  /// Migre une seule fois d'éventuelles anciennes clés globales vers l'utilisateur déjà connecté,
  /// puis supprime les anciennes clés globales pour empêcher toute fuite vers d'autres comptes.
  Future<void> _migrateLegacyGlobalKeysIfNeeded() async {
    if (_prefs.getBool(_keyLegacyMigrated) == true) return;
    if (accountScope == 'guest') return;

    await _migrateStringListKeyIfMissing(_keyFavoriteArtists);
    await _migrateStringListKeyIfMissing(_keySearchHistory);
    await _migrateStringListKeyIfMissing(_keyLocalFiles);

    for (final key in const [
      _keyProfileImagePath,
      _keySearchedArtists,
      _keySuperlikes,
      _keyFavoriteAlbums,
      _keyLifetimePlays,
      _keyWeeklyPlaylists,
      _keyUserBio,
    ]) {
      await _migrateStringKeyIfMissing(key);
    }

    final scopedWeeklyTsKey = _scopedKey(_keyWeeklyPlaylistsTs);
    if (!_prefs.containsKey(scopedWeeklyTsKey) &&
        _prefs.containsKey(_keyWeeklyPlaylistsTs)) {
      final ts = _prefs.getInt(_keyWeeklyPlaylistsTs);
      if (ts != null) {
        await _prefs.setInt(scopedWeeklyTsKey, ts);
      }
    }

    final scopedLyricsKey = _scopedKey(_keyFreeLyricsMode);
    if (!_prefs.containsKey(scopedLyricsKey) && _prefs.containsKey(_keyFreeLyricsMode)) {
      await _prefs.setBool(
        scopedLyricsKey,
        _prefs.getBool(_keyFreeLyricsMode) ?? false,
      );
    }

    for (final tabId in const ['favorites', 'playlists', 'history', 'downloads', 'local']) {
      await _migrateStringKeyIfMissing('${_keyViewMode}_$tabId');
      await _migrateStringKeyIfMissing('${_keySortMode}_$tabId');
    }

    await _clearLegacyGlobalKeys();
    await _prefs.setBool(_keyLegacyMigrated, true);
  }

  Future<void> _clearLegacyGlobalKeys() async {
    for (final key in const [
      _keyFavoriteArtists,
      _keySearchHistory,
      _keyProfileImagePath,
      _keySearchedArtists,
      _keyLocalFiles,
      _keyFreeLyricsMode,
      _keySuperlikes,
      _keyFavoriteAlbums,
      _keyLifetimePlays,
      _keyWeeklyPlaylists,
      _keyWeeklyPlaylistsTs,
      _keyUserBio,
    ]) {
      await _prefs.remove(key);
    }
    for (final tabId in const ['favorites', 'playlists', 'history', 'downloads', 'local']) {
      await _prefs.remove('${_keyViewMode}_$tabId');
      await _prefs.remove('${_keySortMode}_$tabId');
    }
  }

  /// Indique qu'une migration héritée ne doit plus s'appliquer à un tout nouveau compte.
  Future<void> suppressLegacyMigrationForNewAccount() async {
    await _clearLegacyGlobalKeys();
    await _prefs.setBool(_keyLegacyMigrated, true);
  }

  // Token management
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
  }

  String? get accessToken => _cachedAccessToken;
  String? get refreshToken => _cachedRefreshToken;

  bool get isAuthenticated =>
      _cachedAccessToken != null && _cachedAccessToken!.isNotEmpty;

  // App-wide First Launch Onboarding (3 slides + welcome choice)
  bool get hasSeenAppOnboarding {
    if (_prefs.getBool(_keyAppOnboardingDone) == true) return true;
    // Rétrocompatibilité stricte : ne jamais réafficher aux utilisateurs ayant déjà ouvert/utilisé l'app.
    if (_prefs.getBool(_keyOnboardingSeen) == true) return true;
    if (isAuthenticated || username.isNotEmpty || email.isNotEmpty) return true;
    if ((_prefs.getStringList(_keyFavoriteArtists) ?? const []).isNotEmpty) {
      return true;
    }
    return false;
  }

  Future<void> setAppOnboardingCompleted(bool value) async {
    await _prefs.setBool(_keyAppOnboardingDone, value);
    await _prefs.setBool(_keyOnboardingSeen, value);
  }

  // Rétrocompatibilité des anciens getters
  bool get hasSeenOnboarding => hasSeenAppOnboarding;
  Future<void> setOnboardingSeen(bool value) => setAppOnboardingCompleted(value);

  bool hasSeenOnboardingFor(String targetEmail) {
    final norm = targetEmail.trim().toLowerCase();
    if (norm.isEmpty) return false;
    final done = _prefs.getBool('artist_onboarding_done_$norm');
    if (done != null) return done;
    final legacy = _prefs.getBool('${_keyOnboardingSeen}_$norm');
    if (legacy == true) return true;
    final artists = _prefs.getStringList('${_keyFavoriteArtists}_$norm');
    return artists != null && artists.isNotEmpty;
  }

  Future<void> setOnboardingSeenFor(String targetEmail, bool value) async {
    final norm = targetEmail.trim().toLowerCase();
    if (norm.isNotEmpty) {
      await _prefs.setBool('artist_onboarding_done_$norm', value);
      await _prefs.setBool('${_keyOnboardingSeen}_$norm', value);
    }
    if (value) {
      await setAppOnboardingCompleted(true);
    }
  }

  bool get hasCompletedArtistOnboarding {
    if (accountScope == 'guest') return false;
    if (hasSeenOnboardingFor(accountScope)) return true;
    return getFavoriteArtists().isNotEmpty;
  }

  // User Profile
  Future<void> saveUserInfo({
    required String username,
    required String email,
    bool isNewAccount = false,
  }) async {
    await _prefs.setString(_keyUsername, username.trim());
    await _prefs.setString(_keyEmail, email.trim().toLowerCase());
    if (isNewAccount) {
      await suppressLegacyMigrationForNewAccount();
    } else {
      await _migrateLegacyGlobalKeysIfNeeded();
    }
    refreshAccountNotifiers();
  }

  String get username => _prefs.getString(_keyUsername) ?? '';
  String get email => _prefs.getString(_keyEmail) ?? '';

  // Search History (isolé par compte)
  List<String> getSearchHistory() {
    return List<String>.from(_prefs.getStringList(_scopedKey(_keySearchHistory)) ?? []);
  }

  Future<void> addSearchQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final history = getSearchHistory();
    history.removeWhere((q) => q.toLowerCase() == clean.toLowerCase());
    history.insert(0, clean);
    if (history.length > 10) {
      history.removeRange(10, history.length);
    }
    await _prefs.setStringList(_scopedKey(_keySearchHistory), history);
  }

  Future<void> clearSearchHistory() async {
    await _prefs.remove(_scopedKey(_keySearchHistory));
  }

  // --- LIBRARY UI PREFERENCES (isolées par compte) ---
  String getViewMode(String tabId) {
    final scoped = _prefs.getString(_scopedKey('${_keyViewMode}_$tabId'));
    if (scoped != null) return scoped;
    if (_prefs.getBool(_keyLegacyMigrated) != true) {
      final legacy = _prefs.getString('${_keyViewMode}_$tabId');
      if (legacy != null) return legacy;
    }
    return 'list';
  }

  Future<void> saveViewMode(String tabId, String mode) async {
    await _prefs.setString(_scopedKey('${_keyViewMode}_$tabId'), mode);
  }

  String getSortMode(String tabId) {
    final scoped = _prefs.getString(_scopedKey('${_keySortMode}_$tabId'));
    if (scoped != null) return scoped;
    if (_prefs.getBool(_keyLegacyMigrated) != true) {
      final legacy = _prefs.getString('${_keySortMode}_$tabId');
      if (legacy != null) return legacy;
    }
    return 'alpha';
  }

  Future<void> saveSortMode(String tabId, String mode) async {
    await _prefs.setString(_scopedKey('${_keySortMode}_$tabId'), mode);
  }

  // Local Audio Files (isolés par compte)
  List<String> getLocalFiles() {
    return List<String>.from(_prefs.getStringList(_scopedKey(_keyLocalFiles)) ?? []);
  }

  Future<void> saveLocalFiles(List<String> paths) async {
    await _prefs.setStringList(_scopedKey(_keyLocalFiles), paths);
  }

  // Profile Image Path (isolé par compte)
  String? getProfileImagePath() {
    return _prefs.getString(_scopedKey(_keyProfileImagePath));
  }

  Future<void> saveProfileImagePath(String path) async {
    await _prefs.setString(_scopedKey(_keyProfileImagePath), path);
  }

  Future<void> removeProfileImagePath() async {
    await _prefs.remove(_scopedKey(_keyProfileImagePath));
  }

  // Favorite Artists (strictement isolés par compte + sync serveur optionnelle)
  List<String> getFavoriteArtists() {
    return List<String>.from(_prefs.getStringList(_scopedKey(_keyFavoriteArtists)) ?? []);
  }

  Future<void> saveFavoriteArtists(
    List<String> artists, {
    bool syncToServer = true,
  }) async {
    final cleaned = <String>[];
    final seen = <String>{};
    for (final raw in artists) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      if (seen.add(name.toLowerCase())) {
        cleaned.add(name);
      }
    }
    await _prefs.setStringList(_scopedKey(_keyFavoriteArtists), cleaned);
    favoriteArtistsNotifier.value = List<String>.unmodifiable(cleaned);
    if (syncToServer && onFavoriteArtistsSaved != null && isAuthenticated) {
      try {
        await onFavoriteArtistsSaved!(cleaned);
      } catch (_) {}
    }
  }

  List<String> getFollowedArtists() => getFavoriteArtists();
  Future<void> saveFollowedArtists(List<String> artists) => saveFavoriteArtists(artists);

  Future<void> saveUsername(String newName) async {
    await _prefs.setString(_keyUsername, newName.trim());
  }

  bool isArtistFollowed(String artistName) {
    final target = artistName.trim().toLowerCase();
    return getFavoriteArtists().any((a) => a.trim().toLowerCase() == target);
  }

  Future<bool> toggleFollowArtist(String artistName) async {
    final clean = artistName.trim();
    if (clean.isEmpty) return false;
    final list = List<String>.from(getFavoriteArtists());
    final idx = list.indexWhere((a) => a.trim().toLowerCase() == clean.toLowerCase());
    if (idx >= 0) {
      list.removeAt(idx);
      await saveFavoriteArtists(list);
      return false;
    } else {
      list.add(clean);
      await saveFavoriteArtists(list);
      return true;
    }
  }

  // Free Lyrics Mode (isolé par compte)
  bool get isFreeLyricsMode {
    return _prefs.getBool(_scopedKey(_keyFreeLyricsMode)) ?? false;
  }

  Future<void> setFreeLyricsMode(bool value) async {
    await _prefs.setBool(_scopedKey(_keyFreeLyricsMode), value);
  }

  // User Bio & Customizations (isolés par compte)
  String get userBio {
    return _prefs.getString(_scopedKey('user_bio')) ??
        'Passionné de musique sur Sonoritiz';
  }

  Future<void> saveUserBio(String bio) async {
    await _prefs.setString(_scopedKey('user_bio'), bio);
  }

  // Audio & App Preferences (isolées par compte)
  String get streamingQuality =>
      _prefs.getString(_scopedKey('pref_streaming_quality')) ??
      _prefs.getString('pref_streaming_quality') ??
      'haute';
  Future<void> setStreamingQuality(String value) =>
      _prefs.setString(_scopedKey('pref_streaming_quality'), value);

  String get downloadQuality =>
      _prefs.getString(_scopedKey('pref_download_quality')) ??
      _prefs.getString('pref_download_quality') ??
      'haute';
  Future<void> setDownloadQuality(String value) =>
      _prefs.setString(_scopedKey('pref_download_quality'), value);

  bool get autoplayEnabled =>
      _prefs.getBool(_scopedKey('pref_autoplay_enabled')) ??
      _prefs.getBool('pref_autoplay_enabled') ??
      true;
  Future<void> setAutoplayEnabled(bool value) =>
      _prefs.setBool(_scopedKey('pref_autoplay_enabled'), value);

  bool get volumeNormalizationEnabled =>
      _prefs.getBool(_scopedKey('pref_volume_normalization')) ??
      _prefs.getBool('pref_volume_normalization') ??
      true;
  Future<void> setVolumeNormalizationEnabled(bool value) =>
      _prefs.setBool(_scopedKey('pref_volume_normalization'), value);

  bool get pushNotificationsEnabled =>
      _prefs.getBool(_scopedKey('pref_push_notifications')) ??
      _prefs.getBool('pref_push_notifications') ??
      true;
  Future<void> setPushNotificationsEnabled(bool value) =>
      _prefs.setBool(_scopedKey('pref_push_notifications'), value);
  Future<void> savePushNotificationsEnabled(bool value) =>
      setPushNotificationsEnabled(value);

  String get audioPreset =>
      _prefs.getString(_scopedKey('pref_audio_preset')) ??
      _prefs.getString('pref_audio_preset') ??
      'Studio';
  Future<void> setAudioPreset(String value) =>
      _prefs.setString(_scopedKey('pref_audio_preset'), value);

  int get crossfadeSeconds =>
      (_prefs.getInt(_scopedKey('pref_crossfade_seconds')) ?? 0).clamp(0, 12);
  Future<void> setCrossfadeSeconds(int seconds) =>
      _prefs.setInt(_scopedKey('pref_crossfade_seconds'), seconds.clamp(0, 12));

  bool get concertModeEnabled =>
      _prefs.getBool(_scopedKey('pref_concert_mode')) ?? false;
  Future<void> setConcertModeEnabled(bool value) =>
      _prefs.setBool(_scopedKey('pref_concert_mode'), value);

  List<double> get customEqBands {
    final raw = _prefs.getString(_scopedKey('pref_custom_eq_bands'));
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List && list.length == 5) {
          return list
              .map((e) => (e is num ? e.toDouble() : 0.0).clamp(-1.0, 1.0))
              .toList();
        }
      } catch (_) {}
    }
    return const <double>[0.0, 0.0, 0.0, 0.0, 0.0];
  }

  Future<void> setCustomEqBands(List<double> bands) async {
    final normalized = List<double>.generate(
      5,
      (i) => i < bands.length ? bands[i].clamp(-1.0, 1.0) : 0.0,
    );
    await _prefs.setString(
      _scopedKey('pref_custom_eq_bands'),
      jsonEncode(normalized),
    );
  }

  String get lyricsTranslationLang =>
      _prefs.getString(_scopedKey('pref_lyrics_translation_lang')) ?? '';
  Future<void> setLyricsTranslationLang(String langCode) =>
      _prefs.setString(_scopedKey('pref_lyrics_translation_lang'), langCode);

  // Style du lecteur ('vertical' pour Signature Sonoritiz ou 'default' pour Classique Immersif)
  String get playerStyle {
    final rawStyle = _prefs.getString(_scopedKey('pref_player_style')) ??
        _prefs.getString('pref_player_style');
    if (rawStyle == 'special' || rawStyle == 'immersive' || rawStyle == null) {
      return 'vertical';
    }
    return rawStyle;
  }

  Future<void> setPlayerStyle(String value) async {
    final clean = (value == 'special' || value == 'immersive') ? 'vertical' : value;
    playerStyleNotifier.value = clean;
    await _prefs.setString(_scopedKey('pref_player_style'), clean);
  }

  // Compteur cumulatif des écoutes depuis la création du compte (isolé par compte)
  String get _lifetimePlaysKey => _scopedKey('lifetime_plays');

  Map<String, dynamic> getLifetimeTrackPlaysRaw() {
    final raw = _prefs.getString(_lifetimePlaysKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  Future<void> recordLifetimeTrackPlay(Map<String, dynamic> trackJson) async {
    if (!isAuthenticated && accountScope == 'guest') return;
    final title = (trackJson['title'] ?? '').toString().trim().toLowerCase();
    final artist = (trackJson['artist_name'] ?? trackJson['artist'] ?? '').toString().trim().toLowerCase();
    final rawId = (trackJson['id'] ?? trackJson['youtube_id'] ?? '').toString();

    final trackKey = (title.isNotEmpty && artist.isNotEmpty)
        ? '${title}__$artist'
        : (rawId.isNotEmpty ? rawId : null);
    if (trackKey == null) return;

    final current = getLifetimeTrackPlaysRaw();
    final existing = current[trackKey] ?? (rawId.isNotEmpty ? current[rawId] : null);
    int currentCount = 0;
    List<String> timestamps = [];
    if (existing is Map) {
      if (existing['count'] is int) {
        currentCount = existing['count'] as int;
      }
      if (existing['play_timestamps'] is List) {
        timestamps = List<String>.from((existing['play_timestamps'] as List).map((e) => e.toString()));
      }
    }
    final nowIso = DateTime.now().toIso8601String();
    timestamps.add(nowIso);
    if (timestamps.length > 200) {
      timestamps = timestamps.sublist(timestamps.length - 200);
    }

    current[trackKey] = {
      'count': currentCount + 1,
      'track': trackJson,
      'last_played_at': nowIso,
      'play_timestamps': timestamps,
    };
    await _prefs.setString(_lifetimePlaysKey, jsonEncode(current));
    if (_isPodcastOrBookJson(trackJson)) {
      await recordRecentPodcastPlay(trackJson);
    }
  }

  static bool _isPodcastOrBookJson(Map<String, dynamic> map) {
    final lowerId =
        (map['id'] ?? map['youtube_id'] ?? '').toString().trim().toLowerCase();
    if (lowerId.startsWith('deezer_podcast_') ||
        lowerId.startsWith('deezer_pod_') ||
        lowerId.startsWith('deezer_book_') ||
        lowerId.startsWith('itunes_pod_') ||
        lowerId.startsWith('itunes_book_')) {
      return true;
    }
    final lowerGenre = (map['genre'] ?? '').toString().trim().toLowerCase();
    return lowerGenre.contains('podcast') ||
        lowerGenre.contains('livre') ||
        lowerGenre.contains('audiobook') ||
        lowerGenre == 'fun & vidéo';
  }

  // --- SONORITIZ SUPERLIKES (MAX 20, isolés par compte) ---
  String get _superlikesKey => _scopedKey(_keySuperlikes);

  List<Map<String, dynamic>> getSuperlikesRaw() {
    final raw = _prefs.getString(_superlikesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveSuperlikesRaw(
    List<Map<String, dynamic>> list, {
    bool syncToServer = true,
  }) async {
    final clamped = list
        .take(20)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    await _prefs.setString(_superlikesKey, jsonEncode(clamped));
    if (syncToServer && onSuperlikesSaved != null && isAuthenticated) {
      try {
        await onSuperlikesSaved!(clamped);
      } catch (_) {}
    }
  }

  // --- ALBUMS FAVORIS (isolés par compte) ---
  String get _favoriteAlbumsKey => _scopedKey(_keyFavoriteAlbums);

  List<Map<String, dynamic>> getFavoriteAlbumsRaw() {
    final raw = _prefs.getString(_favoriteAlbumsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveFavoriteAlbumsRaw(
    List<Map<String, dynamic>> list, {
    bool syncToServer = true,
  }) async {
    final normalized = list.map((e) => Map<String, dynamic>.from(e)).toList();
    await _prefs.setString(_favoriteAlbumsKey, jsonEncode(normalized));
    if (syncToServer && onFavoriteAlbumsSaved != null && isAuthenticated) {
      try {
        await onFavoriteAlbumsSaved!(normalized);
      } catch (_) {}
    }
  }

  // --- SUIVI DES ARTISTES RECHERCHÉS (historique par compte + sélection diverse neutre) ---
  String get _searchedArtistsKey => _scopedKey(_keySearchedArtists);

  /// Retourne uniquement les artistes réellement recherchés par le compte actif (jamais les défauts).
  List<Map<String, dynamic>> getUserSearchedArtistsRaw() {
    final raw = _prefs.getString(_searchedArtistsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  List<Map<String, dynamic>> getTopSearchedArtists({int limit = 14}) {
    final list = getUserSearchedArtistsRaw();

    // Sélection cosmopolite et équilibrée uniquement utilisée pour compléter la vitrine Recherche
    const defaultArtists = [
      {'id': '1447935', 'name': 'The Weeknd', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/d1297e5ea7a407e3ea2adcb9657c96a7/500x500-000000-80-0-0.jpg'},
      {'id': '12246', 'name': 'Taylor Swift', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/88a782f23a55f4a53d957c85c510a26c/500x500-000000-80-0-0.jpg'},
      {'id': '1109731', 'name': 'Burna Boy', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/6a56eef40d42b3bf705aaef60c0df4e6/500x500-000000-80-0-0.jpg'},
      {'id': '892', 'name': 'Charles Aznavour', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/92d2f07b11938a85a989b445303f827c/500x500-000000-80-0-0.jpg'},
      {'id': '384236', 'name': 'Ed Sheeran', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/2a03401e09457595d3cf5014174c34c9/500x500-000000-80-0-0.jpg'},
      {'id': '868310322', 'name': 'Locko', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/b6fba35940989f6d1945f32a76f23602/500x500-000000-80-0-0.jpg'},
      {'id': '75798', 'name': 'Adele', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/9b82a596a7f6d9e59ff838bb4cb787f8/500x500-000000-80-0-0.jpg'},
      {'id': '136338472', 'name': 'Tiakola', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/9c16bc37d8009dfec08655c63fc74d08/500x500-000000-80-0-0.jpg'},
      {'id': '70603750', 'name': 'Fally Ipupa', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/8ee208bf3b839aa03a0a430ee81fae7f/500x500-000000-80-0-0.jpg'},
      {'id': '246791', 'name': 'Drake', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/5d2fa7848f2203fa16ec4ecbcf82e982/500x500-000000-80-0-0.jpg'},
      {'id': '14363907', 'name': 'Ayra Starr', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/f1ff9f0ef9cfb87b74404fae1ffbfa02/500x500-000000-80-0-0.jpg'},
      {'id': '412', 'name': 'Queen', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/7b9c33731317a499c3c55daee1320b9f/500x500-000000-80-0-0.jpg'},
      {'id': '1749842238', 'name': 'Tayc', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/01fc8b548b8cba8c08ecfe086c5f7d23/500x500-000000-80-0-0.jpg'},
      {'id': '142986206', 'name': 'Libianca', 'image': 'https://e-cdns-images.dzcdn.net/images/artist/1e7aaeeef117326dfeb157db6efcb2b7/500x500-000000-80-0-0.jpg'},
    ];

    final existingNames = list.map((a) => (a['name'] ?? '').toString().toLowerCase()).toSet();
    for (final def in defaultArtists) {
      if (!existingNames.contains(def['name']!.toLowerCase())) {
        list.add(Map<String, dynamic>.from(def));
        if (list.length >= limit) break;
      }
    }

    return list.take(limit).toList();
  }

  Future<void> recordSearchedArtist(Map<String, dynamic> artist) async {
    final name = (artist['name'] ?? '').toString().trim();
    if (name.isEmpty) return;

    final list = getUserSearchedArtistsRaw();
    list.removeWhere((a) => (a['name'] ?? '').toString().toLowerCase() == name.toLowerCase());

    list.insert(0, {
      'id': (artist['id'] ?? '').toString(),
      'name': name,
      'image': (artist['picture_medium'] ?? artist['picture'] ?? artist['image'] ?? '').toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _prefs.setString(_searchedArtistsKey, jsonEncode(list.take(20).toList()));
  }

  // --- CACHE DES 5 PLAYLISTS PERSONNALISÉES SUR 7 JOURS (isolé par compte) ---
  String get _weeklyPlaylistsKey => _scopedKey('weekly_curated_playlists_v3');

  String get _weeklyPlaylistsTimestampKey =>
      _scopedKey('weekly_curated_playlists_ts_v3');

  List<Map<String, dynamic>>? getWeeklyPlaylists() {
    final raw = _prefs.getString(_weeklyPlaylistsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveWeeklyPlaylists(List<Map<String, dynamic>> playlists) async {
    try {
      await _prefs.setString(_weeklyPlaylistsKey, jsonEncode(playlists));
      await _prefs.setInt(
        _weeklyPlaylistsTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Ne jamais bloquer le chargement de l'accueil si la sérialisation échoue
    }
  }

  Future<void> clearWeeklyPlaylistsCache() async {
    await _prefs.remove(_weeklyPlaylistsKey);
    await _prefs.remove(_weeklyPlaylistsTimestampKey);
  }

  DateTime? getWeeklyPlaylistsTimestamp() {
    final ms = _prefs.getInt(_weeklyPlaylistsTimestampKey);
    if (ms == null || ms == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Extrait les pistes jouées localement pour le compte actif triées de la plus récente à la plus ancienne.
  List<Map<String, dynamic>> getRecentLocalTrackEntries({int? withinDays}) {
    final rawMap = getLifetimeTrackPlaysRaw();
    if (rawMap.isEmpty) return [];

    final DateTime? cutoff = withinDays != null
        ? DateTime.now().subtract(Duration(days: withinDays))
        : null;

    final List<Map<String, dynamic>> entries = [];
    for (final value in rawMap.values) {
      if (value is! Map) continue;
      final track = value['track'];
      if (track is! Map) continue;

      final lastStr = (value['last_played_at'] ?? '').toString();
      final lastDt = DateTime.tryParse(lastStr);
      if (cutoff != null && (lastDt == null || lastDt.isBefore(cutoff))) {
        continue;
      }

      int recentCount = 0;
      if (withinDays != null && cutoff != null && value['play_timestamps'] is List) {
        for (final ts in value['play_timestamps'] as List) {
          final dt = DateTime.tryParse(ts.toString());
          if (dt != null && !dt.isBefore(cutoff)) {
            recentCount++;
          }
        }
      } else {
        recentCount = value['count'] is int ? value['count'] as int : 1;
      }
      if (recentCount == 0 && cutoff != null) recentCount = 1;

      entries.add({
        'track': Map<String, dynamic>.from(track),
        'last_played_ms': lastDt?.millisecondsSinceEpoch ?? 0,
        'recent_count': recentCount,
      });
    }

    entries.sort(
      (a, b) => (b['last_played_ms'] as int).compareTo(a['last_played_ms'] as int),
    );
    return entries;
  }

  // --- REPRISE EXACTE DE LA POSITION DE LECTURE (isolée par compte) ---
  String get _lastPlaybackPosTrackKey => _scopedKey('last_playback_track_id');
  String get _lastPlaybackPosSecKey => _scopedKey('last_playback_position_sec');
  String get _podcastResumeMapKey => _scopedKey('podcast_resume_positions_v1');

  Future<void> saveLastPlaybackPosition(String trackId, int seconds) async {
    final cleanId = trackId.trim();
    if (cleanId.isEmpty || seconds < 0) return;
    await _prefs.setString(_lastPlaybackPosTrackKey, cleanId);
    await _prefs.setInt(_lastPlaybackPosSecKey, seconds);

    // Mémoriser aussi la position propre à chaque podcast/livre écouté récemment
    final rawRecent = _prefs.getString(_recentPodcastsKey);
    if (rawRecent != null && rawRecent.contains(cleanId)) {
      try {
        final rawMap = _prefs.getString(_podcastResumeMapKey);
        final Map<String, dynamic> map = (rawMap != null && rawMap.isNotEmpty)
            ? Map<String, dynamic>.from(jsonDecode(rawMap) as Map)
            : <String, dynamic>{};
        map[cleanId] = seconds;
        if (map.length > 40) {
          map.remove(map.keys.first);
        }
        await _prefs.setString(_podcastResumeMapKey, jsonEncode(map));
      } catch (_) {}
    }
  }

  int getLastPlaybackPositionSeconds(String trackId) {
    final savedId = _prefs.getString(_lastPlaybackPosTrackKey);
    if (savedId != trackId.trim()) return 0;
    return _prefs.getInt(_lastPlaybackPosSecKey) ?? 0;
  }

  int getPodcastResumeSeconds(String trackId) {
    if (!_prefsInitialized) return 0;
    final cleanId = trackId.trim();
    if (cleanId.isEmpty) return 0;
    try {
      final rawMap = _prefs.getString(_podcastResumeMapKey);
      if (rawMap != null && rawMap.isNotEmpty) {
        final decoded = jsonDecode(rawMap);
        if (decoded is Map && decoded[cleanId] is num) {
          return (decoded[cleanId] as num).toInt();
        }
      }
    } catch (_) {}
    return getLastPlaybackPositionSeconds(cleanId);
  }

  // --- PODCASTS ÉCOUTÉS RÉCEMMENT (isolés par compte) ---
  String get _recentPodcastsKey => _scopedKey('recent_podcasts_v1');

  List<Map<String, dynamic>> getRecentPodcastsRaw({int limit = 16}) {
    if (!_prefsInitialized) return const [];
    final List<Map<String, dynamic>> result = [];
    final Set<String> seenKeys = {};

    void addIfPodcast(Map<String, dynamic> rawTrack) {
      final id = (rawTrack['id'] ?? rawTrack['youtube_id'] ?? '')
          .toString()
          .trim();
      final title = (rawTrack['title'] ?? '').toString().trim();
      if (id.isEmpty || title.isEmpty) return;
      final dedup = '${id}__${title.toLowerCase()}';
      if (seenKeys.contains(id) || seenKeys.contains(dedup)) return;
      seenKeys.add(id);
      seenKeys.add(dedup);
      result.add(Map<String, dynamic>.from(rawTrack));
    }

    final raw = _prefs.getString(_recentPodcastsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              addIfPodcast(Map<String, dynamic>.from(item));
            }
          }
        }
      } catch (_) {}
    }

    // Compléter avec les podcasts éventuellement déjà présents dans l'historique local
    for (final entry in getRecentLocalTrackEntries()) {
      final trackMap = entry['track'];
      if (trackMap is Map<String, dynamic> && _isPodcastOrBookJson(trackMap)) {
        addIfPodcast(trackMap);
      }
      if (result.length >= limit) break;
    }

    return result.take(limit).toList();
  }

  Future<void> recordRecentPodcastPlay(Map<String, dynamic> trackJson) async {
    if (!_prefsInitialized) return;
    final id = (trackJson['id'] ?? trackJson['youtube_id'] ?? '')
        .toString()
        .trim();
    final title = (trackJson['title'] ?? '').toString().trim();
    if (id.isEmpty || title.isEmpty) return;

    final existing = getRecentPodcastsRaw(limit: 24);
    existing.removeWhere((item) {
      final itemId =
          (item['id'] ?? item['youtube_id'] ?? '').toString().trim();
      final itemTitle = (item['title'] ?? '').toString().trim().toLowerCase();
      return itemId == id || itemTitle == title.toLowerCase();
    });

    final enriched = Map<String, dynamic>.from(trackJson);
    if ((enriched['genre'] ?? '').toString().trim().isEmpty) {
      enriched['genre'] = 'Podcast';
    }
    existing.insert(0, enriched);
    final capped = existing.take(20).toList();
    await _prefs.setString(_recentPodcastsKey, jsonEncode(capped));
    recentPodcastsNotifier.value = capped;
  }

  // --- RECOMMANDATIONS SONORITIZ CONNECT (sons proposés par les invités uniquement) ---
  String get _connectGuestRecsKey =>
      _scopedKey('connect_guest_recommendations_v1');

  List<Map<String, dynamic>> getConnectGuestRecommendationsRaw({
    int limit = 24,
  }) {
    if (!_prefsInitialized) return const [];
    final raw = _prefs.getString(_connectGuestRecsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((m) =>
                (m['id'] ?? '').toString().trim().isNotEmpty &&
                (m['title'] ?? '').toString().trim().isNotEmpty)
            .take(limit)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> recordConnectGuestRecommendations(
    List<Map<String, dynamic>> guestTracks,
  ) async {
    if (!_prefsInitialized || guestTracks.isEmpty) return;
    final current = List<Map<String, dynamic>>.from(
      getConnectGuestRecommendationsRaw(limit: 30),
    );
    bool changed = false;

    for (final rawTrack in guestTracks.reversed) {
      final id = (rawTrack['id'] ?? '').toString().trim();
      final title = (rawTrack['title'] ?? '').toString().trim();
      if (id.isEmpty || title.isEmpty) continue;
      final existingIdx =
          current.indexWhere((t) => (t['id'] ?? '').toString().trim() == id);
      if (existingIdx != -1) {
        continue;
      }
      current.insert(0, Map<String, dynamic>.from(rawTrack));
      changed = true;
    }

    if (!changed) return;
    final capped = current.take(30).toList();
    await _prefs.setString(_connectGuestRecsKey, jsonEncode(capped));
    connectRecommendationsNotifier.value = capped;
  }

  // --- SONORITIZ LYRICS (10 sons aimés/superlikés • renouvelés tous les 5 jours) ---
  String get _sonoritizLyricsTracksKey =>
      _scopedKey('sonoritiz_lyrics_tracks_v1');
  String get _sonoritizLyricsTsKey => _scopedKey('sonoritiz_lyrics_ts_v1');

  List<Map<String, dynamic>>? getCachedSonoritizLyricsTracks() {
    if (!_prefsInitialized) return null;
    final raw = _prefs.getString(_sonoritizLyricsTracksKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  DateTime? getSonoritizLyricsTimestamp() {
    if (!_prefsInitialized) return null;
    final ms = _prefs.getInt(_sonoritizLyricsTsKey);
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> saveSonoritizLyricsTracks(
    List<Map<String, dynamic>> tracks, {
    bool updateTimestamp = true,
  }) async {
    if (!_prefsInitialized) return;
    try {
      await _prefs.setString(
        _sonoritizLyricsTracksKey,
        jsonEncode(tracks.take(10).toList()),
      );
      if (updateTimestamp) {
        await _prefs.setInt(
          _sonoritizLyricsTsKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (_) {}
  }

  // --- ONGLET ACTIF DE LA BIBLIOTHÈQUE (mémorisé par compte) ---
  String get _activeLibraryTabKey => _scopedKey('library_active_tab_v1');

  String getActiveLibraryTab() {
    if (!_prefsInitialized) return 'favorites';
    final raw = _prefs.getString(_activeLibraryTabKey);
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();
    return 'favorites';
  }

  Future<void> saveActiveLibraryTab(String tabId) async {
    if (!_prefsInitialized || tabId.trim().isEmpty) return;
    await _prefs.setString(_activeLibraryTabKey, tabId.trim());
  }

  // --- REGISTRE DES VRAIS ALBUMS TÉLÉCHARGÉS (jamais un son individuel isolé) ---
  String get _downloadedAlbumsKey => _scopedKey('downloaded_albums_v1');

  static String computeDownloadedAlbumKey(String id, String title, String artist) {
    final cleanId = id.trim();
    if (cleanId.isNotEmpty && cleanId != '0' && cleanId != '-1') {
      return 'id:$cleanId';
    }
    return 'meta:${title.trim().toLowerCase()}__${artist.trim().toLowerCase()}';
  }

  List<Map<String, dynamic>> getDownloadedAlbumsRaw() {
    if (!_prefsInitialized) return const [];
    final raw = _prefs.getString(_downloadedAlbumsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((m) => (m['title'] ?? '').toString().trim().isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  bool isAlbumRegisteredDownloaded({
    required String id,
    required String title,
    required String artistName,
  }) {
    final targetKey = computeDownloadedAlbumKey(id, title, artistName);
    final normTitle = title.trim().toLowerCase();
    for (final item in getDownloadedAlbumsRaw()) {
      final k = (item['key'] ?? '').toString();
      final itemTitle = (item['title'] ?? '').toString().trim().toLowerCase();
      if (k == targetKey || (normTitle.isNotEmpty && itemTitle == normTitle)) {
        return true;
      }
    }
    return false;
  }

  Future<void> registerDownloadedAlbum({
    required String id,
    required String title,
    required String artistName,
    required String coverUrl,
    required List<String> trackIds,
  }) async {
    if (!_prefsInitialized || title.trim().isEmpty || trackIds.isEmpty) return;
    final key = computeDownloadedAlbumKey(id, title, artistName);
    final current = List<Map<String, dynamic>>.from(getDownloadedAlbumsRaw());
    current.removeWhere((m) =>
        (m['key'] ?? '').toString() == key ||
        ((m['title'] ?? '').toString().trim().toLowerCase() ==
            title.trim().toLowerCase() &&
            (m['artistName'] ?? '').toString().trim().toLowerCase() ==
                artistName.trim().toLowerCase()));

    current.insert(0, <String, dynamic>{
      'key': key,
      'id': id.trim(),
      'title': title.trim(),
      'artistName': artistName.trim(),
      'coverUrl': coverUrl.trim(),
      'trackIds': trackIds,
      'downloadedAt': DateTime.now().toIso8601String(),
    });

    final capped = current.take(60).toList();
    await _prefs.setString(_downloadedAlbumsKey, jsonEncode(capped));
    downloadedAlbumsNotifier.value = capped;
  }

  Future<void> unregisterDownloadedAlbum({
    required String id,
    required String title,
    required String artistName,
  }) async {
    if (!_prefsInitialized) return;
    final key = computeDownloadedAlbumKey(id, title, artistName);
    final current = List<Map<String, dynamic>>.from(getDownloadedAlbumsRaw());
    current.removeWhere((m) =>
        (m['key'] ?? '').toString() == key ||
        (m['title'] ?? '').toString().trim().toLowerCase() ==
            title.trim().toLowerCase());
    await _prefs.setString(_downloadedAlbumsKey, jsonEncode(current));
    downloadedAlbumsNotifier.value = current;
  }

  Future<void> clearSession() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyRefreshToken);
    await _prefs.remove(_keyUsername);
    await _prefs.remove(_keyEmail);
    refreshAccountNotifiers();
  }
}
