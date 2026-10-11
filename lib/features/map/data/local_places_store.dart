import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/map_models.dart';

enum SavedSlot { home, work }

/// Device-local saved places (Home / Work) and recent destinations. Real local feature,
/// stored in SharedPreferences (non-secret). Nothing here is synced to the backend.
class LocalPlacesStore {
  LocalPlacesStore(this._prefs);

  final SharedPreferences _prefs;

  static const _recentsKey = 'places.recents.v1';
  static String _slotKey(SavedSlot s) => 'places.saved.${s.name}.v1';
  static const maxRecents = 5;

  Place? saved(SavedSlot slot) {
    try {
      final raw = _prefs.getString(_slotKey(slot));
      return raw == null
          ? null
          : Place.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> setSaved(SavedSlot slot, Place? place) async {
    if (place == null) {
      await _prefs.remove(_slotKey(slot));
    } else {
      await _prefs.setString(_slotKey(slot), jsonEncode(place.toJson()));
    }
  }

  List<Place> recents() {
    try {
      final raw = _prefs.getString(_recentsKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List)
          .map((e) => Place.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> addRecent(Place place) async {
    final list = [
      place,
      ...recents().where((p) => p.id != place.id),
    ].take(maxRecents).toList();
    await _prefs.setString(
      _recentsKey,
      jsonEncode(list.map((p) => p.toJson()).toList()),
    );
  }
}
