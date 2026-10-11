import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/shared/stitch.dart';

/// Loads the REAL fonts for every test so text/icon metrics match the device. Without this
/// flutter_test renders with the wide "Ahem" font (false overflows) and icons as boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Mask-filter shadows are skipped by the headless renderer: use the image-filter path for QA renders.
  Elevated.useImageFilterShadows = true;

  final inter = FontLoader('packages/nordic_design_kit/Inter');
  for (final file in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(
      rootBundle.load('packages/nordic_design_kit/fonts/Inter-$file.ttf'),
    );
  }
  await inter.load();

  final symbols =
      FontLoader('packages/material_symbols_icons/MaterialSymbolsOutlined')
        ..addFont(
          rootBundle.load(
            'packages/material_symbols_icons/lib/fonts/MaterialSymbolsOutlined.ttf',
          ),
        );
  await symbols.load();

  // Classic Material icons (used by a few framework widgets) from the Flutter SDK.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  final materialIcons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (materialIcons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.sublistView(materialIcons.readAsBytesSync())),
      );
    await loader.load();
  }

  await testMain();
}
