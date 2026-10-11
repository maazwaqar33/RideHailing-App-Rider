import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nordic_design_kit/nordic_design_kit.dart';
import 'package:rider_app/core/providers.dart';
import 'package:rider_app/core/storage/token_store.dart';
import 'package:rider_app/features/auth/domain/auth_models.dart';
import 'package:rider_app/features/rides/domain/ride_models.dart';
import 'package:rider_app/shared/app_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scripted Dio adapter: responds per `METHOD /path` (path relative to the API prefix).
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter();

  final Map<String, FutureOr<ResponseBody> Function(RequestOptions)> _routes =
      {};
  final List<RequestOptions> requests = [];

  void on(
    String method,
    String path,
    FutureOr<ResponseBody> Function(RequestOptions) handler,
  ) {
    _routes['${method.toUpperCase()} $path'] = handler;
  }

  void json(
    String method,
    String path,
    int status,
    Object body, {
    Map<String, List<String>>? headers,
  }) {
    on(method, path, (_) => jsonBody(status, body, headers: headers));
  }

  void networkDown(String method, String path) {
    on(
      method,
      path,
      (o) =>
          throw DioException.connectionError(requestOptions: o, reason: 'down'),
    );
  }

  void timeoutOut(String method, String path) {
    on(
      method,
      path,
      (o) => throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 8),
        requestOptions: o,
      ),
    );
  }

  static ResponseBody jsonBody(
    int status,
    Object body, {
    Map<String, List<String>>? headers,
  }) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...?headers,
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.path;
    final handler = _routes['${options.method} $path'];
    if (handler == null) {
      return jsonBody(404, {'message': 'Resource not found.'});
    }
    return await handler(options);
  }

  @override
  void close({bool force = false}) {}

  List<RequestOptions> where(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).toList();
}

Map<String, dynamic> userJson({
  int id = 7,
  int? riderId = 1,
  String email = 'rider1@example.com',
  String name = 'Kari Hansen',
}) => {
  'id': id,
  'name': name,
  'email': email,
  'phone': null,
  'status': 'active',
  'roles': [
    {'id': 6, 'slug': riderId == null ? 'manager' : 'rider', 'name': 'Rider'},
  ],
  'permissions': ['rides.create'],
  'driver_id': null,
  'rider_id': riderId,
};

Map<String, dynamic> loginJson({int? riderId = 1}) => {
  'token': 'tok_123',
  'token_type': 'Bearer',
  'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
  'user': userJson(riderId: riderId),
};

Map<String, dynamic> breakdownJson({int total = 1744}) => {
  'currency': 'EUR',
  'distance_meters': 4200,
  'duration_seconds': 600,
  'base_fare_minor': 350,
  'distance_charge_minor': 504,
  'time_charge_minor': 300,
  'raw_fare_minor': 1154,
  'minimum_fare_adjustment_minor': 0,
  'fare_minor': 1154,
  'booking_fee_minor': 100,
  'tax_minor': 150,
  'total_minor': total,
};

Map<String, dynamic> rideJson({
  int id = 42,
  String status = 'requested',
  bool withDriver = false,
  String paymentMethod = 'cash',
  int? finalMinor,
  Map<String, dynamic>? timestamps,
  String? cancelReason,
}) => {
  'id': id,
  'status': status,
  'pickup': {
    'latitude': 59.911,
    'longitude': 10.7528,
    'address': 'Oslo S (Jernbanetorget)',
  },
  'dropoff': {
    'latitude': 59.9106,
    'longitude': 10.7298,
    'address': 'Aker Brygge',
  },
  'distance_meters': 4200,
  'duration_seconds': 600,
  'rider': {
    'id': 1,
    'first_name': 'Kari',
    'last_name': 'Hansen',
    'phone': '+4740000001',
  },
  'driver': withDriver
      ? {'id': 3, 'first_name': 'Erik', 'phone': '+4740000099'}
      : null,
  'vehicle': withDriver
      ? {
          'plate_number': 'EL 12345',
          'make': 'Toyota',
          'model': 'Camry',
          'colour': 'Silver',
        }
      : null,
  'fare': {
    'currency': 'EUR',
    'estimate_minor': 1744,
    'final_minor': finalMinor,
    'breakdown': breakdownJson(),
  },
  'payment': {'method': paymentMethod, 'status': 'not_charged'},
  'timestamps': {
    'requested_at': '2026-10-10T10:00:00+00:00',
    'accepted_at': null,
    'driver_en_route_at': null,
    'arrived_at': null,
    'started_at': null,
    'completed_at': status == 'completed' ? '2026-10-10T10:20:00+00:00' : null,
    'cancelled_at': status == 'cancelled' ? '2026-10-10T10:05:00+00:00' : null,
    ...?timestamps,
  },
  'cancellation': status == 'cancelled'
      ? {
          'reason': cancelReason ?? 'Plans changed',
          'cancelled_by_user_id': null,
        }
      : null,
  'timeline': [],
};

Ride sampleRide({
  String status = 'requested',
  bool withDriver = false,
  int id = 42,
}) => Ride.fromJson(rideJson(id: id, status: status, withDriver: withDriver));

const AuthUser sampleUser = AuthUser(
  id: 7,
  name: 'Kari Hansen',
  email: 'rider1@example.com',
  riderId: 1,
);

/// Provider overrides every widget test needs: in-memory prefs/token store and a blank map tile layer.
Future<List<Override>> baseOverrides({
  TokenStore? tokenStore,
  Map<String, Object>? prefs,
}) async {
  SharedPreferences.setMockInitialValues(prefs ?? {});
  final sp = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(sp),
    tokenStoreProvider.overrideWithValue(tokenStore ?? InMemoryTokenStore()),
    mapTileLayerProvider.overrideWithValue((_) => const SizedBox.shrink()),
  ];
}

/// Wraps a screen in the Nordic theme with a ProviderScope.
Widget wrapApp(Widget child, {required List<Override> overrides}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: NordicTheme.light(), home: child),
    );
