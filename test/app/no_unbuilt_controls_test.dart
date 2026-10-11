import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Client-demo rule: anything that is not built is removed from the UI, never disabled, badged
/// "Soon"/"Unavailable" or answered with a "not available" message. This guards against regressions.
void main() {
  test('lib/ has no "unavailable feature" UI helpers or copy', () {
    final banned = <Pattern>[
      'showUnavailable',
      'UnavailableTag',
      'UnavailableActionTile',
      RegExp('coming soon', caseSensitive: false),
      RegExp(r"Text\(\s*'Soon'"),
      RegExp('not available yet', caseSensitive: false),
      RegExp('is unavailable', caseSensitive: false),
      "'Unavailable'",
      RegExp(r'onTap:\s*\(\)\s*\{\s*\}'),
      RegExp(r'onPressed:\s*\(\)\s*\{\s*\}'),
    ];
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      for (final b in banned) {
        if (text.contains(b)) offenders.add('${f.path}: $b');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
