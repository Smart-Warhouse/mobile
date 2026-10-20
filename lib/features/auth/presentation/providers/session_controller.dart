import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/json/json_reader.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/result.dart';
import '../../../../core/network/server_url.dart';
import '../../../../core/providers.dart';
import '../../../../core/storage/app_storage.dart';
import '../../data/auth_repository.dart';
import '../../data/models/user.dart';

sealed class SessionState {
  const SessionState();
}

class SessionBootstrapping extends SessionState {
  const SessionBootstrapping();
}

class SignedOut extends SessionState {
  const SignedOut({this.expired = false});

  /// The token was rejected (401 or WS 4401): tell the person why.
  final bool expired;
}

class SignedIn extends SessionState {
  const SignedIn({
    required this.user,
    required this.token,
    required this.baseUrl,
  });

  final User user;
  final String token;
  final String baseUrl;

  bool get canOperate => user.role.canOperate;
}

/// Owns the session: restore on launch, login, sign-out (incl. on 401/4401).
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(_restore);
    return const SessionBootstrapping();
  }

  AppPrefs get _prefs => ref.read(appPrefsProvider);
  SecretStore get _secrets => ref.read(secretStoreProvider);

  /// Builds its own Dio: [apiDioProvider] depends on this notifier, so it
  /// must not be read from here (Riverpod circular dependency).
  AuthRepository _repo(
    String baseUrl, {
    String? token,
    bool watch401 = false,
  }) => AuthRepository(
    createApiDio(
      baseUrl: baseUrl,
      adapter: ref.read(httpAdapterProvider),
      token: () => token,
      language: () => ref.read(localeProvider).languageCode,
      onUnauthorized: watch401 ? () => signOut(expired: true) : () {},
    ),
  );

  Future<void> _restore() async {
    final baseUrl = _prefs.serverUrl;
    final token = await _secrets.read(AppPrefs.tokenKey);
    final userJson = _prefs.cachedUser;
    final expiresAt = _prefs.tokenExpiresAt;
    if (!ref.mounted) return;
    User? user;
    if (userJson != null) {
      try {
        user = User.fromJson(JsonReader(userJson));
      } on JsonContractException {
        user = null;
      }
    }
    final expired =
        expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt);
    // The server is fixed at build time: a session saved for another address
    // (an older build, or the LAN server) has to sign in again.
    final otherServer =
        baseUrl != normalizeServerUrl(AppPrefs.defaultServerUrl);
    if (baseUrl == null ||
        otherServer ||
        token == null ||
        user == null ||
        expired) {
      if (token != null) await _secrets.delete(AppPrefs.tokenKey);
      if (ref.mounted) state = SignedOut(expired: expired);
      return;
    }
    // Signed in from the cache so the floor app opens even when the server
    // is momentarily unreachable; the token is verified right after.
    state = SignedIn(user: user, token: token, baseUrl: baseUrl);
    unawaited(refreshMe());
  }

  /// Re-reads `GET /api/auth/me` (role changes). A 401 signs out through
  /// the interceptor; a network failure keeps the cached session.
  Future<void> refreshMe() async {
    final current = state;
    if (current is! SignedIn) return;
    final res = await _repo(
      current.baseUrl,
      token: current.token,
      watch401: true,
    ).me();
    if (!ref.mounted) return;
    if (res case Ok(:final value)) {
      final now = state;
      if (now is SignedIn && now.token == current.token) {
        state = SignedIn(user: value, token: now.token, baseUrl: now.baseUrl);
        await _prefs.setCachedUser(value.toJson());
      }
    }
  }

  Future<Result<User>> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final res = await _repo(baseUrl).login(username, password);
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final grant):
        await _secrets.write(AppPrefs.tokenKey, grant.accessToken);
        await _prefs.setServerUrl(baseUrl);
        await _prefs.setLastUsername(username);
        await _prefs.setCachedUser(grant.user.toJson());
        await _prefs.setTokenExpiresAt(
          grant.expiresIn == null
              ? null
              : DateTime.now().toUtc().add(Duration(seconds: grant.expiresIn!)),
        );
        if (ref.mounted) {
          state = SignedIn(
            user: grant.user,
            token: grant.accessToken,
            baseUrl: baseUrl,
          );
        }
        return Ok(grant.user);
    }
  }

  Future<void> signOut({bool expired = false}) async {
    if (state is SignedOut) return;
    state = SignedOut(expired: expired);
    await _secrets.delete(AppPrefs.tokenKey);
    await _prefs.setCachedUser(null);
    await _prefs.setTokenExpiresAt(null);
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// The signed-in user's role allows commands (operator/admin).
final canOperateProvider = Provider<bool>(
  (ref) => switch (ref.watch(sessionControllerProvider)) {
    SignedIn(:final canOperate) => canOperate,
    _ => false,
  },
);

/// Convenience for screens that only exist while signed in.
final currentUserProvider = Provider<User?>(
  (ref) => switch (ref.watch(sessionControllerProvider)) {
    SignedIn(:final user) => user,
    _ => null,
  },
);
