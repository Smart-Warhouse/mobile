import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/presentation/providers/session_controller.dart';
import 'network/api_client.dart';
import 'realtime/live_socket.dart';
import 'storage/app_storage.dart';

/// Overridden in `main()` with the loaded instance (and in tests).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final appPrefsProvider = Provider<AppPrefs>(
  (ref) => AppPrefs(ref.watch(sharedPreferencesProvider)),
);

final secretStoreProvider = Provider<SecretStore>((ref) => SecureSecretStore());

/// Test seam: a fake HTTP adapter for every Dio the app builds.
final httpAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// Test seam: how `/ws/live` channels are opened (null = real socket).
final channelFactoryProvider = Provider<ChannelFactory?>((ref) => null);

/// The UI language. Arabic (RTL) is the default (docs/05-design-system.md).
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final code = ref.watch(appPrefsProvider).localeCode;
    return Locale(code == 'en' ? 'en' : 'ar');
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref.read(appPrefsProvider).setLocaleCode(locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

/// Dio for the server the person signed in to.
final apiDioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(
    sessionControllerProvider.select(
      (s) => s is SignedIn ? s.baseUrl : AppPrefs.defaultServerUrl,
    ),
  );
  return createApiDio(
    baseUrl: baseUrl,
    adapter: ref.watch(httpAdapterProvider),
    token: () => switch (ref.read(sessionControllerProvider)) {
      SignedIn(:final token) => token,
      _ => null,
    },
    language: () => ref.read(localeProvider).languageCode,
    onUnauthorized: () =>
        ref.read(sessionControllerProvider.notifier).signOut(expired: true),
  );
});
