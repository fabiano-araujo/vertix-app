import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/series_model.dart';

/// Local My List / watchlist, Netflix-style.
class WatchlistService {
  WatchlistService._internal();
  static final WatchlistService _instance = WatchlistService._internal();
  factory WatchlistService() => _instance;

  static const _storageKey = 'vertix_watchlist';
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  List<SeriesModel> _items = [];
  bool _loaded = false;

  List<SeriesModel> get items => List.unmodifiable(_items);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _items = decoded
            .whereType<Map>()
            .map((item) => SeriesModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    }
    _loaded = true;
  }

  bool contains(int seriesId) => _items.any((item) => item.id == seriesId);

  Future<bool> toggle(SeriesModel series) async {
    await ensureLoaded();
    if (contains(series.id)) {
      _items.removeWhere((item) => item.id == series.id);
      await _persist();
      return false;
    }
    _items.insert(0, series);
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
    revision.value++;
  }
}
