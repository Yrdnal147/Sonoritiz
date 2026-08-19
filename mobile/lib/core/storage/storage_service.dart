import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyOnboardingSeen = 'onboarding_seen';
  static const String _keyUsername = 'username';
  static const String _keyEmail = 'email';
  static const String _keySearchHistory = 'search_history';
  static const String _keyViewMode = 'library_view_mode';
  static const String _keySortMode = 'library_sort_mode';
  static const String _keyLocalFiles = 'local_audio_files';
  static const String _keyProfileImagePath = 'profile_image_path';

  late SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // In-memory cache for synchronous access
  String? _cachedAccessToken;
  String? _cachedRefreshToken;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Pre-load tokens into memory
    _cachedAccessToken = await _secureStorage.read(key: _keyAccessToken);
    _cachedRefreshToken = await _secureStorage.read(key: _keyRefreshToken);
  }

  // Token management
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
  }

  String? get accessToken => _cachedAccessToken;
  String? get refreshToken => _cachedRefreshToken;

  bool get isAuthenticated => _cachedAccessToken != null && _cachedAccessToken!.isNotEmpty;

  // Onboarding
  bool get hasSeenOnboarding => _prefs.getBool(_keyOnboardingSeen) ?? false;
  Future<void> setOnboardingSeen(bool value) async {
    await _prefs.setBool(_keyOnboardingSeen, value);
  }

  // User Profile
  Future<void> saveUserInfo({required String username, required String email}) async {
    await _prefs.setString(_keyUsername, username);
    await _prefs.setString(_keyEmail, email);
  }

  String get username => _prefs.getString(_keyUsername) ?? '';
  String get email => _prefs.getString(_keyEmail) ?? '';

  // Search History
  List<String> getSearchHistory() {
    return _prefs.getStringList(_keySearchHistory) ?? [];
  }

  Future<void> addSearchQuery(String query) async {
    final history = getSearchHistory();
    history.remove(query); // Remove if exists to put it at the top
    history.insert(0, query);
    if (history.length > 10) {
      history.removeLast(); // Keep only last 10
    }
    await _prefs.setStringList(_keySearchHistory, history);
  }

  Future<void> clearSearchHistory() async {
    await _prefs.remove(_keySearchHistory);
  }

  // --- LIBRARY UI PREFERENCES ---
  String getViewMode(String tabId) {
    return _prefs.getString('${_keyViewMode}_$tabId') ?? 'list';
  }

  Future<void> saveViewMode(String tabId, String mode) async {
    await _prefs.setString('${_keyViewMode}_$tabId', mode);
  }

  String getSortMode(String tabId) {
    return _prefs.getString('${_keySortMode}_$tabId') ?? 'alpha';
  }

  Future<void> saveSortMode(String tabId, String mode) async {
    await _prefs.setString('${_keySortMode}_$tabId', mode);
  }

  // Local Audio Files
  List<String> getLocalFiles() {
    return _prefs.getStringList(_keyLocalFiles) ?? [];
  }

  Future<void> saveLocalFiles(List<String> paths) async {
    await _prefs.setStringList(_keyLocalFiles, paths);
  }

  static const String _keyFavoriteArtists = 'favorite_artists';

  // Profile Image Path
  String? getProfileImagePath() {
    return _prefs.getString(_keyProfileImagePath);
  }

  Future<void> saveProfileImagePath(String path) async {
    await _prefs.setString(_keyProfileImagePath, path);
  }

  Future<void> removeProfileImagePath() async {
    await _prefs.remove(_keyProfileImagePath);
  }

  // Favorite Artists
  List<String> getFavoriteArtists() {
    return _prefs.getStringList(_keyFavoriteArtists) ?? [];
  }

  Future<void> saveFavoriteArtists(List<String> artists) async {
    await _prefs.setStringList(_keyFavoriteArtists, artists);
  }

  // Free Lyrics Mode
  static const String _keyFreeLyricsMode = 'is_free_lyrics_mode';
  
  bool get isFreeLyricsMode {
    return _prefs.getBool(_keyFreeLyricsMode) ?? false;
  }
  
  Future<void> setFreeLyricsMode(bool value) async {
    await _prefs.setBool(_keyFreeLyricsMode, value);
  }

  Future<void> clearSession() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyRefreshToken);
    await _prefs.remove(_keyUsername);
    await _prefs.remove(_keyEmail);
  }
}
