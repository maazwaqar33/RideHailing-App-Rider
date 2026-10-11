import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Real Esri World Street Map tiles downloaded once (and cached in .dart_tool/qa_tiles) with dart:io and served from memory.
///
/// `flutter test` cannot complete NetworkImage tile loads, so the live map renders download the
/// tiles themselves (HTTP to the real tile server) and hand them to flutter_map through this
/// provider. The tiles, style and URL are exactly what the app requests on a device.
class PrefetchedTileProvider extends TileProvider {
  PrefetchedTileProvider(this._tiles);

  final Map<String, Uint8List> _tiles;

  static final _transparent = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  ImageProvider getImage(TileCoordinates c, TileLayer options) {
    // The URL carries the real zoom (retina mode requests one level deeper) in {z}/{y}/{x} order.
    final parts = Uri.parse(getTileUrl(c, options)).pathSegments;
    final key =
        '${parts[parts.length - 3]}/${parts.last}/${parts[parts.length - 2]}';
    final hit = _tiles[key];
    if (hit == null) debugPrint('MISSING TILE $key');
    return MemoryImage(hit ?? _transparent);
  }

  static (int, int) tileOf(LatLng p, int z) {
    final n = math.pow(2, z).toDouble();
    final x = ((p.longitude + 180) / 360 * n).floor();
    final latRad = p.latitude * math.pi / 180;
    final y =
        ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
                2 *
                n)
            .floor();
    return (x, y);
  }

  /// Downloads tiles around [centers] for the given zoom levels (radius in tiles per zoom).
  static Future<PrefetchedTileProvider> load(
    List<LatLng> centers, {
    Map<int, int> radiusByZoom = const {
      9: 1,
      10: 1,
      11: 2,
      12: 2,
      13: 3,
      14: 4,
      15: 3,
      16: 2,
    },
  }) async {
    final client = HttpClient()
      ..userAgent = 'com.nordicmobility.rider_app (QA render, cached)';
    final tiles = <String, Uint8List>{};
    final queue = <Future<void> Function()>[];
    for (final c in centers) {
      radiusByZoom.forEach((z, r) {
        final (cx, cy) = tileOf(c, z);
        for (var x = cx - r; x <= cx + r; x++) {
          for (var y = cy - r; y <= cy + r; y++) {
            final key = '$z/$x/$y';
            if (tiles.containsKey(key)) continue;
            tiles[key] = Uint8List(0);
            queue.add(() async {
              try {
                final cached = File('.dart_tool/qa_tiles_esri/$z-$x-$y.jpg');
                if (cached.existsSync()) {
                  tiles[key] = cached.readAsBytesSync();
                  return;
                }
                final req = await client.getUrl(
                  Uri.parse(
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/$z/$y/$x',
                  ),
                );
                final resp = await req.close();
                final bytes = await resp.fold<BytesBuilder>(
                  BytesBuilder(),
                  (b, d) => b..add(d),
                );
                if (resp.statusCode == 200) {
                  final data = bytes.takeBytes();
                  tiles[key] = data;
                  cached.parent.createSync(recursive: true);
                  cached.writeAsBytesSync(data);
                }
              } catch (_) {
                // leave empty: filtered out below
              }
            });
          }
        }
      });
    }
    for (var i = 0; i < queue.length; i += 24) {
      await Future.wait(queue.skip(i).take(24).map((f) => f()));
    }
    client.close();
    tiles.removeWhere((_, v) => v.isEmpty);
    return PrefetchedTileProvider(tiles);
  }
}
