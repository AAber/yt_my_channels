import 'package:hive/hive.dart';
import '../models/series.dart';
import '../models/lesson.dart';

class LocalStorageService {
  static const String _seriesBoxName = 'series_cache';
  static const String _countsBoxName = 'last_known_counts';
  static const String _feedBoxName = 'feed_cache';
  static const String _feedKey = 'recent_lessons_v2';
  static const String _feedTimestampKey = 'recent_lessons_ts_v2';
  // Cache TTL: 1 hour
  static const int _feedTtlMs = 60 * 60 * 1000;

  Box? _seriesBox;
  Box? _countsBox;
  Box? _feedBox;

  Future<void> init() async {
    _seriesBox = await Hive.openBox(_seriesBoxName);
    _countsBox = await Hive.openBox(_countsBoxName);
    _feedBox = await Hive.openBox(_feedBoxName);
  }
  
  // Series cache
  Future<void> cacheSeries(List<Series> seriesList) async {
    await _seriesBox?.clear();
    for (final series in seriesList) {
      await _seriesBox?.put(series.slug, series.toJson());
    }
  }
  
  List<Series> getCachedSeries() {
    if (_seriesBox == null) return [];
    return _seriesBox!.values
        .map((json) => Series.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
  
  // Last known counts
  Future<void> saveCounts(Map<String, int> counts) async {
    for (final entry in counts.entries) {
      await _countsBox?.put(entry.key, {
        'lessonCount': entry.value,
        'lastChecked': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
  
  Map<String, int> getLastKnownCounts() {
    if (_countsBox == null) return {};
    final counts = <String, int>{};
    for (final key in _countsBox!.keys) {
      final value = _countsBox!.get(key);
      if (value != null) {
        counts[key] = value['lessonCount'] as int;
      }
    }
    return counts;
  }
  
  int? getLastKnownCount(String seriesSlug) {
    if (_countsBox == null) return null;
    final value = _countsBox!.get(seriesSlug);
    if (value == null) return null;
    return value['lessonCount'] as int?;
  }
  
  Future<void> updateCount(String seriesSlug, int count) async {
    await _countsBox?.put(seriesSlug, {
      'lessonCount': count,
      'lastChecked': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  // Feed cache
  Future<void> cacheFeedLessons(List<Lesson> lessons) async {
    final raw = lessons.map((l) => l.toJson()).toList();
    await _feedBox?.put(_feedKey, raw);
    await _feedBox?.put(_feedTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Returns cached lessons if they exist and are within TTL, otherwise null.
  List<Lesson>? getCachedFeedLessons() {
    if (_feedBox == null) return null;
    final ts = _feedBox!.get(_feedTimestampKey) as int?;
    if (ts == null) return null;
    if (DateTime.now().millisecondsSinceEpoch - ts > _feedTtlMs) return null;
    final raw = _feedBox!.get(_feedKey);
    if (raw == null) return null;
    return (raw as List)
        .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> clearFeedCache() async {
    await _feedBox?.delete(_feedKey);
    await _feedBox?.delete(_feedTimestampKey);
  }

  // Find new lessons
  List<Series> findNewLessons(List<Series> currentSeries) {
    final newLessons = <Series>[];
    for (final series in currentSeries) {
      final lastCount = getLastKnownCount(series.slug);
      if (lastCount == null || series.lessonCount > lastCount) {
        newLessons.add(series);
      }
    }
    return newLessons;
  }
}
