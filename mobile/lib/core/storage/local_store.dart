import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/models/user.dart';

class LocalStore {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _themeKey = 'theme_mode';
  static const _shopFilterKey = 'admin_shop_filter';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveSession(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  static Future<void> saveShopFilter(String? shopId) async {
    final prefs = await SharedPreferences.getInstance();
    if (shopId == null) {
      await prefs.remove(_shopFilterKey);
    } else {
      await prefs.setString(_shopFilterKey, shopId);
    }
  }

  static Future<String?> getShopFilter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_shopFilterKey);
  }
}
