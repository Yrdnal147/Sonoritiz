import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyOnboardingSeen = 'onboarding_seen';
  static const String _keyUsername = 'username';
  static const String _keyEmail = 'email';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token management
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _prefs.setString(_keyAccessToken, accessToken);
    await _prefs.setString(_keyRefreshToken, refreshToken);
  }

  String? get accessToken => _prefs.getString(_keyAccessToken);
  String? get refreshToken => _prefs.getString(_keyRefreshToken);

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;

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

  Future<void> clearSession() async {
    await _prefs.remove(_keyAccessToken);
    await _prefs.remove(_keyRefreshToken);
    await _prefs.remove(_keyUsername);
    await _prefs.remove(_keyEmail);
  }
}
