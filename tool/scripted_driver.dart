// SCRIPTED DRIVER - NOT the Driver App.
//
// There is no Driver App in this workspace. To exercise the Rider app's real status
// polling against the real backend, this script plays the driver through the public API:
//
//   1. dispatcher/manager  POST rides/{id}/assign {driver_id}      (requested -> offered)
//   2. driver1             POST rides/{id}/status accepted         (offered -> accepted)
//   3. driver1             ... driver_en_route -> arrived -> in_progress -> completed
//
// Pure Dart (dio only) so it works both as a CLI and from the live integration test:
//
//   dart run tool/scripted_driver.dart --ride 42 [--delay 5] [--base http://127.0.0.1:8001]
//
// Because it is a script, "two phones" cross-device acceptance is NOT verified by it.
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

const kDemoPassword = 'Password123!';

class ScriptedDriver {
  ScriptedDriver({
    String baseUrl = 'http://127.0.0.1:8001',
    this.password = kDemoPassword,
    this.log = _stdoutLog,
  }) : _baseUrl = '$baseUrl/api/v1';

  final String _baseUrl;
  final String password;
  final void Function(String) log;

  static void _stdoutLog(String m) => stdout.writeln('[scripted-driver] $m');

  Dio _client([String? token]) => Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      validateStatus: (_) => true,
      connectTimeout: const Duration(seconds: 8),
    ),
  );

  /// Logs in and returns an authenticated client plus the user JSON.
  Future<(Dio, Map<String, dynamic>)> login(String email) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final r = await _client().post<dynamic>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'device_name': 'scripted-driver',
        },
      );
      if (r.statusCode == 200) {
        final body = Map<String, dynamic>.from(r.data as Map);
        return (
          _client(body['token'] as String),
          Map<String, dynamic>.from(body['user'] as Map),
        );
      }
      if (r.statusCode == 429) {
        await Future<void>.delayed(const Duration(seconds: 15));
        continue;
      }
      throw StateError('login failed for $email: ${r.statusCode} ${r.data}');
    }
    throw StateError('login rate-limited for $email');
  }

  /// Plays the whole lifecycle for [rideId]. [stepDelay] is the pause between statuses so a
  /// polling client can observe each one. [onStep] is called after every successful transition.
  Future<void> run(
    int rideId, {
    Duration stepDelay = const Duration(seconds: 6),
    String driverEmail = 'driver1@example.com',
    String dispatcherEmail = 'dispatcher@example.com',
    void Function(String status)? onStep,
    bool completeTrip = true,
  }) async {
    final (driverDio, driverUser) = await login(driverEmail);
    final driverId = driverUser['driver_id'] as int;
    final (dispatcherDio, _) = await login(dispatcherEmail);

    log('dispatcher assigns ride $rideId to driver $driverId');
    final assign = await dispatcherDio.post<dynamic>(
      '/rides/$rideId/assign',
      data: {'driver_id': driverId},
    );
    _expectOk(assign, 'assign');
    onStep?.call('offered');
    await Future<void>.delayed(stepDelay);

    final statuses = [
      'accepted',
      'driver_en_route',
      'arrived',
      'in_progress',
      if (completeTrip) 'completed',
    ];
    for (final status in statuses) {
      final r = await driverDio.post<dynamic>(
        '/rides/$rideId/status',
        data: {'status': status},
      );
      _expectOk(r, 'status $status');
      log('driver set $status');
      onStep?.call(status);
      if (status != statuses.last) await Future<void>.delayed(stepDelay);
    }
  }

  /// Throws when the API did not answer 2xx.
  void _expectOk(Response<dynamic> r, String what) {
    if (r.statusCode == null || r.statusCode! >= 300) {
      throw StateError('$what failed: ${r.statusCode} ${r.data}');
    }
  }
}

Future<void> main(List<String> args) async {
  String? arg(String name, [String? fallback]) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final ride = int.tryParse(arg('ride') ?? '');
  if (ride == null) {
    stderr.writeln(
      'usage: dart run tool/scripted_driver.dart --ride <id> [--delay <seconds>] [--base <url>] [--no-complete]',
    );
    exit(64);
  }
  final delay = Duration(seconds: int.tryParse(arg('delay', '6')!) ?? 6);
  await ScriptedDriver(
    baseUrl: arg('base', 'http://127.0.0.1:8001')!,
  ).run(ride, stepDelay: delay, completeTrip: !args.contains('--no-complete'));
  stdout.writeln(
    '[scripted-driver] done (this was a script, not the Driver App)',
  );
}
