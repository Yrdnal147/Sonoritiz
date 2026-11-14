import 'dart:convert';
import 'package:hive/hive.dart';

/// Petit cache disque (Hive) pour afficher instantanément le dernier contenu
/// connu d'une page (accueil, bibliothèque...) pendant que les données
/// fraîches se rechargent discrètement en arrière-plan.
class JsonCache {
  static const String _boxName = 'json_cache';
  static Box<String>? _box;

  static Future<Box<String>> _open() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  static Future<void> write(String key, Object? json) async {
    try {
      final box = await _open();
      await box.put(key, jsonEncode(json));
    } catch (_) {}
  }

  static Future<dynamic> read(String key) async {
    try {
      final box = await _open();
      final raw = box.get(key);
      if (raw == null) return null;
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(String key) async {
    try {
      final box = await _open();
      await box.delete(key);
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      final box = await _open();
      await box.clear();
    } catch (_) {}
  }
}
