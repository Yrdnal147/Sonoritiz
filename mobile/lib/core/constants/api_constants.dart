import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Base URLs
  static String get baseUrl {
    return 'https://sonoritiz.vercel.app';
  }

  static String get wsBaseUrl {
    // Vercel ne supporte pas les websockets, donc on utilise wss par défaut
    // (cela fonctionnera si on passe sur Render plus tard)
    return 'wss://sonoritiz.vercel.app';
  }

  // Endpoints Auth
  static const String register = '/api/accounts/register/';
  static const String login = '/api/accounts/login/';
  static const String refresh = '/api/accounts/refresh/';
  static const String profile = '/api/accounts/me/';
  static const String passwordReset = '/api/accounts/password-reset/';
  static const String passwordResetConfirm = '/api/accounts/password-reset-confirm/';
  static const String googleLogin = '/api/accounts/google-login/';

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
