import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../agent/models.dart';
import 'calendar_special_cases.dart';
import 'data_source.dart';
import 'sefaria_calendar.dart';

class SefariaAdapter implements DataSource {
  final String baseUrl = 'https://www.sefaria.org/api';
  final Duration cacheTtl = const Duration(hours: 1);

  @override
  String get name => 'sefaria';

  @override
  Future<List<SourceResult>> search(IntentResult intent) async {
    try {
      final results = <SourceResult>[];
      final needsCalendar = intent.parsha != null &&
              (intent.parsha == 'השבוע' || intent.parsha!.contains('השבוע')) ||
          intent.dafYomi != null &&
              (intent.dafYomi == 'היום' || intent.dafYomi!.contains('היום'));

      SefariaCalendarSnapshot? snapshot;
      if (needsCalendar) {
        snapshot = await SefariaCalendar.fetchSnapshot(
          diaspora: false,
          logOutput: false,
        );
      }

      final query = _buildSearchQuery(intent, snapshot);
      if (query.isEmpty &&
          snapshot?.weeklyParsha == null &&
          snapshot?.dafYomi == null) {
        return [];
      }

      if (snapshot?.weeklyParsha != null && snapshot!.weeklyParsha!.isResolved) {
        results.add(_parshaSourceResult(snapshot.weeklyParsha!));
      }
      if (snapshot?.dafYomi != null && snapshot!.dafYomi!.isResolved) {
        results.add(_dafYomiSourceResult(snapshot.dafYomi!));
      }

      if (query.isNotEmpty) {
        final cachedResults = await _getCachedResults(query);
        if (cachedResults != null) {
          results.addAll(cachedResults);
        } else {
          final searchHits = await _searchSefaria(query, intent.limit);
          await _cacheResults(query, searchHits);
          results.addAll(searchHits);
        }
      }

      return results.take(intent.limit).toList();
    } catch (e) {
      print('Error searching Sefaria: $e');
      return [];
    }
  }

  SourceResult _parshaSourceResult(WeeklyParsha parsha) {
    return SourceResult(
      title: 'פרשת ${parsha.hebrewName} — פרשת השבוע',
      teacher: 'ספריא',
      source: name,
      score: 1.0,
      snippet: [
        'מקור: ${parsha.ref}',
        if (parsha.englishName.isNotEmpty) '($parsha.englishName)',
        if (parsha.haftarahHebrew != null) 'הפטרה: ${parsha.haftarahHebrew}',
      ].join(' • '),
      metadata: {
        'type': 'sefaria_calendar',
        'calendar_case': CalendarSpecialCases.parshaWeekly,
        'ref': parsha.ref,
        'url': parsha.url ??
            'https://www.sefaria.org/${parsha.ref.replaceAll(' ', '_')}',
        'hebrew_name': parsha.hebrewName,
        'english_name': parsha.englishName,
      },
    );
  }

  SourceResult _dafYomiSourceResult(DafYomi daf) {
    return SourceResult(
      title: 'דף יומי — ${daf.hebrewDisplay}',
      teacher: 'ספריא',
      source: name,
      score: 1.0,
      snippet: 'מקור: ${daf.ref}${daf.englishDisplay.isNotEmpty ? ' (${daf.englishDisplay})' : ''}',
      metadata: {
        'type': 'sefaria_calendar',
        'calendar_case': CalendarSpecialCases.dafYomi,
        'ref': daf.ref,
        'url': daf.url,
        'hebrew_display': daf.hebrewDisplay,
        'english_display': daf.englishDisplay,
        'tractate_he': daf.tractateHe,
      },
    );
  }

  String _buildSearchQuery(
    IntentResult intent,
    SefariaCalendarSnapshot? snapshot,
  ) {
    final parts = <String>[];

    if (intent.topic != null) parts.add(intent.topic!);
    if (intent.book != null) parts.add(intent.book!);

    if (intent.parsha != null) {
      final p = intent.parsha!.trim();
      if (p == 'השבוע' || p.contains('השבוע')) {
        final parsha = snapshot?.weeklyParsha;
        if (parsha != null && parsha.hebrewName.isNotEmpty) {
          parts.add(parsha.hebrewName);
          parts.add('פרשת ${parsha.hebrewName}');
        }
      } else {
        parts.add(p);
        parts.add('פרשת $p');
      }
    }

    if (intent.dafYomi != null) {
      final d = intent.dafYomi!.trim();
      if (d == 'היום' || d.contains('היום')) {
        final daf = snapshot?.dafYomi;
        if (daf != null) parts.addAll(daf.searchTerms());
      } else {
        parts.add(d);
        parts.add('דף יומי');
        parts.add('דף יומי $d');
      }
    }

    return parts.join(' ').trim();
  }

  Future<List<SourceResult>> _searchSefaria(String query, int limit) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url =
        '$baseUrl/search-wrapper?query=$encodedQuery&type=text&limit=$limit';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Sefaria API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final results = <SourceResult>[];

    if (data['hits'] != null) {
      for (final hit in data['hits']) {
        final score = (hit['score'] ?? 0.0).toDouble() / 100.0;

        results.add(SourceResult(
          title: hit['title'] ?? '',
          teacher: null,
          source: name,
          score: score.clamp(0.0, 1.0),
          snippet: _createSnippet(hit),
          metadata: {
            'ref': hit['ref'],
            'url': hit['url'],
            'category': hit['category'],
            'type': 'sefaria_text',
          },
        ));
      }
    }

    return results;
  }

  String _createSnippet(Map<String, dynamic> hit) {
    final ref = hit['ref']?.toString() ?? '';
    final category = hit['category']?.toString() ?? '';
    final content = hit['content']?.toString() ?? '';

    final parts = <String>[];
    if (ref.isNotEmpty) parts.add('מקור: $ref');
    if (category.isNotEmpty) parts.add('קטגוריה: $category');

    if (content.isNotEmpty) {
      final preview =
          content.length > 100 ? '${content.substring(0, 100)}...' : content;
      parts.add(preview);
    }

    return parts.join(' • ');
  }

  Future<List<SourceResult>?> _getCachedResults(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'sefaria_$query';
      final timestampKey = '${cacheKey}_timestamp';

      final cachedData = prefs.getString(cacheKey);
      final timestamp = prefs.getInt(timestampKey);

      if (cachedData != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheTime) < cacheTtl) {
          final List<dynamic> jsonList = jsonDecode(cachedData);
          return jsonList.map((json) => SourceResult.fromJson(json)).toList();
        }
      }
    } catch (e) {
      print('Error reading cache: $e');
    }
    return null;
  }

  Future<void> _cacheResults(String query, List<SourceResult> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'sefaria_$query';
      final timestampKey = '${cacheKey}_timestamp';

      final jsonList = results.map((r) => r.toJson()).toList();
      await prefs.setString(cacheKey, jsonEncode(jsonList));
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error caching results: $e');
    }
  }

  Future<String?> getText(String ref) async {
    try {
      final encodedRef = Uri.encodeComponent(ref);
      final url = '$baseUrl/texts/$encodedRef';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['text'] is List) {
          return (data['text'] as List).join(' ');
        } else if (data['text'] is String) {
          return data['text'];
        }
      }
    } catch (e) {
      print('Error fetching Sefaria text: $e');
    }
    return null;
  }
}
