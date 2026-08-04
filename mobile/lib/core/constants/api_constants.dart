import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Base URLs (Support Android Emulator 10.0.2.2, iOS / Web 127.0.0.1)
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://192.168.1.171:8000'; // IP locale pour appareil physique
    return 'http://127.0.0.1:8000';
  }

  static String get wsBaseUrl {
    if (kIsWeb) return 'ws://127.0.0.1:8000';
    if (Platform.isAndroid) return 'ws://192.168.1.171:8000'; // IP locale pour appareil physique
    return 'ws://127.0.0.1:8000';
  }

  // Endpoints Auth
  static const String register = '/api/auth/register/';
  static const String login = '/api/auth/login/';
  static const String refresh = '/api/auth/refresh/';
  static const String profile = '/api/auth/me/';

  // Endpoints Catalogue
  static const String trendingTracks = '/api/tracks/trending/';
  static const String searchTracks = '/api/tracks/search/';
  static const String genres = '/api/genres/';

  // Endpoints Favoris, Playlists, Historique
  static const String favorites = '/api/favorites/';
  static const String playlists = '/api/playlists/';
  static const String history = '/api/history/';

  // Endpoints Connect
  static const String connectSessions = '/api/connect/sessions/';
  static const String connectJoin = '/api/connect/sessions/join/';
}
