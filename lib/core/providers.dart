import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/application/session_controller.dart';
import '../features/auth/domain/auth_repository.dart';
import '../mock/mock_auth_repository.dart';
import 'config/env.dart';
import 'network/api_client.dart';
import 'network/base_url_resolver.dart';
import 'storage/token_store.dart';

/// Overridden in `main()` once `SharedPreferences.getInstance()` has resolved.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Backend origin picker (probes 127.0.0.1 / 10.0.2.2 on Android when no API_BASE_URL is given).
final baseUrlResolverProvider = Provider<BaseUrlResolver>(
  (ref) => BaseUrlResolver(candidates: Env.apiBaseUrlCandidates),
);

final dioProvider = Provider<Dio>((ref) {
  return createApiClient(
    tokenStore: ref.watch(tokenStoreProvider),
    resolver: ref.watch(baseUrlResolverProvider),
    // Read lazily: the session controller itself depends on the repository -> dio.
    onUnauthorized: () =>
        ref.read(sessionControllerProvider.notifier).handleUnauthorized(),
  );
});

final mockAuthRepositoryProvider = Provider<MockAuthRepository>(
  (ref) => MockAuthRepository(ref.watch(sharedPreferencesProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ref.watch(mockAuthRepositoryProvider),
);
