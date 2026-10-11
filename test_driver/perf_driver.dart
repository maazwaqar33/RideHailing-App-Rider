import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Writes one `<key>.timeline_summary.json` per traced scenario into `$PERF_OUT` (default
/// `build/perf`). The summaries are computed inside the app from `FrameTiming` (see
/// integration_test/perf_test.dart), so no VM-service connection is needed.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final dir = Directory(Platform.environment['PERF_OUT'] ?? 'build/perf')
      ..createSync(recursive: true);
    for (final entry in data.entries) {
      File('${dir.path}/${entry.key}.timeline_summary.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(entry.value),
      );
    }
  },
);
