import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

// This provider is overridden at startup with the actual SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(prefs);
});

// ThemeMode state notifier
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final StorageService _storage;
  ThemeModeNotifier(this._storage) : super(_resolveThemeMode(_storage.getThemeMode()));

  static ThemeMode _resolveThemeMode(String mode) {
    switch (mode) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final str = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system';
    await _storage.setThemeMode(str);
    state = mode;
  }
}

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // --- Auth Tokens ---
  Future<bool> setAccessToken(String token) async {
    return _prefs.setString(AppConstants.tokenKey, token);
  }

  String? getAccessToken() {
    return _prefs.getString(AppConstants.tokenKey);
  }

  Future<bool> setRefreshToken(String token) async {
    return _prefs.setString(AppConstants.refreshTokenKey, token);
  }

  String? getRefreshToken() {
    return _prefs.getString(AppConstants.refreshTokenKey);
  }

  // --- User Profile ---
  Future<bool> setUser(Map<String, dynamic> userMap) async {
    return _prefs.setString(AppConstants.userKey, jsonEncode(userMap));
  }

  Map<String, dynamic>? getUser() {
    final userStr = _prefs.getString(AppConstants.userKey);
    if (userStr != null) {
      return jsonDecode(userStr) as Map<String, dynamic>;
    }
    return null;
  }

  // --- Restaurant ---
  Future<bool> setRestaurant(Map<String, dynamic> restMap) async {
    return _prefs.setString(AppConstants.restaurantKey, jsonEncode(restMap));
  }

  Map<String, dynamic>? getRestaurant() {
    final restStr = _prefs.getString(AppConstants.restaurantKey);
    if (restStr != null) {
      return jsonDecode(restStr) as Map<String, dynamic>;
    }
    return null;
  }

  // --- Theme Mode ---
  Future<bool> setThemeMode(String themeMode) async {
    return _prefs.setString(AppConstants.themeModeKey, themeMode);
  }

  String getThemeMode() {
    return _prefs.getString(AppConstants.themeModeKey) ?? 'system';
  }

  // --- Logout / Clear ---
  Future<void> clearAuth() async {
    await _prefs.remove(AppConstants.tokenKey);
    await _prefs.remove(AppConstants.refreshTokenKey);
    await _prefs.remove(AppConstants.userKey);
    await _prefs.remove(AppConstants.restaurantKey);
  }
}
