import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the JWT lives. The real one is the platform keystore/keychain;
/// tests use [MemorySecretStore].
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
    : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) async {
    try {
      return await _s.read(key: key);
    } catch (_) {
      // A keystore reset (reinstall, OS upgrade) reads as "no token".
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);

  @override
  Future<void> delete(String key) async {
    try {
      await _s.delete(key: key);
    } catch (_) {
      // Nothing to delete.
    }
  }
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Non-secret preferences (shared_preferences). The token never goes here.
class AppPrefs {
  AppPrefs(this._p);

  final SharedPreferences _p;

  static const _serverUrl = 'sw.server_url';
  static const _username = 'sw.last_username';
  static const _locale = 'sw.locale';
  static const _user = 'sw.user';
  static const _expiresAt = 'sw.token_expires_at';

  static const tokenKey = 'sw.access_token';

  /// Default for a fresh install: the warehouse LAN server, or the one baked in
  /// with `--dart-define=SW_SERVER_URL=https://…` (e.g. the hosted demo).
  static const defaultServerUrl = String.fromEnvironment(
    'SW_SERVER_URL',
    defaultValue: 'http://192.168.50.2:8000',
  );

  String? get serverUrl => _p.getString(_serverUrl);
  Future<void> setServerUrl(String v) => _p.setString(_serverUrl, v);

  String? get lastUsername => _p.getString(_username);
  Future<void> setLastUsername(String v) => _p.setString(_username, v);

  String? get localeCode => _p.getString(_locale);
  Future<void> setLocaleCode(String v) => _p.setString(_locale, v);

  Map<String, dynamic>? get cachedUser {
    final raw = _p.getString(_user);
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> setCachedUser(Map<String, dynamic>? v) =>
      v == null ? _p.remove(_user) : _p.setString(_user, jsonEncode(v));

  DateTime? get tokenExpiresAt {
    final ms = _p.getInt(_expiresAt);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> setTokenExpiresAt(DateTime? v) => v == null
      ? _p.remove(_expiresAt)
      : _p.setInt(_expiresAt, v.millisecondsSinceEpoch);
}
