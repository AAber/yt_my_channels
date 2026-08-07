import 'dart:convert';
import 'package:http/http.dart' as http;
import '../agent/models.dart';
import 'data_source.dart';

class Globals {
  static const String apiBaseUrl = 'https://api.isaac770.live';
}

class MeirApiAdapter implements DataSource {
  static const _hebrewStopWords = {
    'של', 'טוב', 'ו', 'כי', 'את', 'או', 'ה', 'זה', 'זו', 'אלה', 'אלו',
    'מה', 'מי', 'איך', 'איפה', 'מתי', 'למה', 'כמו', 'גם', 'רק', 'עוד',
    'כל', 'על', 'ב', 'ל', 'מ', 'מן', 'אל', 'עד', 'היום', 'רב', 'הרב',
    'רבי', 'ר\'', 'שיעור', 'שיעורים', 'מצא', 'תן', 'לי',
  };

  static const _teacherAliases = {
    'מזרחי': ['מזרחי', 'mizrahi', 'mizrachi'],
    'אבינר': ['אבינר', 'aviner'],
    'טאו': ['טאו', 'tao'],
    'שרקי': ['שרקי', 'sharki', 'sharqi'],
    'פיירמן': ['פיירמן', 'fireman', 'feuerman', 'פיירמן'],
    'כץ': ['כץ', 'katz'],
    'מלכה': ['מלכה', 'malca', 'malka'],
    'בן משה': ['בן משה', 'ben moshe'],
  };

  @override
  String get name => 'meir_api';

  @override
  Future<List<SourceResult>> search(IntentResult intent) async {
    try {
      // Skip if user explicitly requested a different source
      if (intent.source != null && intent.source != 'meir_api') {
        print('🔍 MeirApiAdapter: source=${intent.source} ≠ meir_api, skipping');
        return [];
      }

      print('🔍 MeirApiAdapter: Starting search with intent: ${intent.toJson()}');

      final terms = _buildSearchTerms(intent);
      if (terms.isEmpty) {
        final results = <SourceResult>[];
        await _searchNewLessons(intent, results);
        return results.take(intent.limit).toList();
      }

      final byLessonId = <int, SourceResult>{};
      final termHitCount = <int, int>{};

      for (final term in terms) {
        final lessons = await _searchAllApis(term);
        for (final lesson in lessons) {
          final id = _lessonId(lesson);
          if (id == null) continue;
          if (!_matchesIntent(lesson, intent)) continue;

          termHitCount[id] = (termHitCount[id] ?? 0) + 1;
          final candidate = _toSourceResult(lesson, intent, termHits: termHitCount[id]!);

          final existing = byLessonId[id];
          if (existing == null || candidate.score > existing.score) {
            byLessonId[id] = candidate;
          }
        }
      }

      var results = byLessonId.values.toList();
      results.sort((a, b) {
        final idA = a.metadata['lesson_post_id'] as int?;
        final idB = b.metadata['lesson_post_id'] as int?;
        final hitsA = idA != null ? (termHitCount[idA] ?? 0) : 0;
        final hitsB = idB != null ? (termHitCount[idB] ?? 0) : 0;
        if (hitsA != hitsB) return hitsB.compareTo(hitsA);
        return b.score.compareTo(a.score);
      });

      if (results.length < intent.limit) {
        final existingIds = byLessonId.keys.toSet();
        final extra = <SourceResult>[];
        await _searchNewLessons(intent, extra);
        for (final r in extra) {
          final id = r.metadata['lesson_post_id'];
          if (id is int && !existingIds.contains(id)) {
            results.add(r);
            if (results.length >= intent.limit) break;
          }
        }
      }

      print('🔍 MeirApiAdapter: Returning ${results.length} results');
      return results.take(intent.limit).toList();
    } catch (e, stackTrace) {
      print('❌ MeirApiAdapter: Error searching: $e');
      print('❌ MeirApiAdapter: Stack trace: $stackTrace');
      return [];
    }
  }

  List<String> _buildSearchTerms(IntentResult intent) {
    final terms = <String>[];
    void add(String? value) {
      if (value == null || value.trim().isEmpty) return;
      final cleaned = _cleanTerm(value);
      if (cleaned.isNotEmpty && !_hebrewStopWords.contains(cleaned)) {
        terms.add(cleaned);
      }
    }

    add(intent.teacher);
    add(intent.topic);
    add(intent.book);
    _addParshaSearchTerms(intent, terms);
    _addDafYomiSearchTerms(intent, terms);

    return terms.toSet().toList();
  }

  void _addDafYomiSearchTerms(IntentResult intent, List<String> terms) {
    final daf = intent.dafYomi?.trim();
    if (daf == null || daf.isEmpty) return;

    terms.add('דף יומי');
    if (daf == 'היום' || daf.contains('היום')) return;

    terms.add(daf);
    final tractate = daf.split(RegExp(r'[\s׳"\u05F3]+')).first;
    if (tractate.isNotEmpty && tractate != daf) terms.add(tractate);
  }

  void _addParshaSearchTerms(IntentResult intent, List<String> terms) {
    final parsha = intent.parsha?.trim();
    if (parsha == null || parsha.isEmpty) return;

    if (parsha == 'השבוע' || parsha.contains('השבוע')) {
      terms.add('פרש');
      terms.add('פרשת');
      return;
    }

    final name = _cleanParshaName(parsha);
    if (name.isEmpty) return;
    terms.add(name);
    terms.add('פרשת $name');
    terms.add('פרש');
  }

  String _cleanParshaName(String parsha) {
    var t = parsha.trim();
    t = t.replaceAll(RegExp(r'^(פרשת|פרשה)\s+'), '');
    return t.trim();
  }

  String _cleanTerm(String term) {
    var t = term.trim();
    t = t.replaceAll(RegExp(r'^(ה)?רב\s+', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r"^ר['\u05F3]\s*"), '');
    t = t.replaceAll(RegExp(r'^rabbi\s+', caseSensitive: false), '');
    return t.trim();
  }

  Future<List<Map<String, dynamic>>> _searchAllApis(String term) async {
    final results = <Map<String, dynamic>>[];
    final seen = <int>{};

    void addAll(List<Map<String, dynamic>> items) {
      for (final item in items) {
        final id = _lessonId(item);
        if (id != null && seen.add(id)) {
          results.add(item);
        }
      }
    }

    addAll(await _searchWindex(term));
    addAll(await _searchResourcesApi(term));
    return results;
  }

  Future<List<Map<String, dynamic>>> _searchWindex(String term) async {
    try {
      final encodedQuery = Uri.encodeComponent(term);
      final url =
          '${Globals.apiBaseUrl}/api/v3/windex/search?q=$encodedQuery&limit=30';
      print('🔍 MeirApiAdapter: Windex: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode != 200) {
        print('🔍 MeirApiAdapter: Windex error ${response.statusCode}');
        return [];
      }

      final data = json.decode(utf8.decode(response.bodyBytes));
      final searchResults = data['results'] ??
          data['data'] ??
          data['lessons'] ??
          (data is List ? data : []);

      if (searchResults is! List) return [];
      print('🔍 MeirApiAdapter: Windex "$term" → ${searchResults.length}');
      return searchResults.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ MeirApiAdapter: Windex error for "$term": $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchResourcesApi(String term) async {
    try {
      final encoded = Uri.encodeComponent(term);
      final url = '${Globals.apiBaseUrl}/api/v3/resources/search?key=$encoded';
      print('🔍 MeirApiAdapter: Resources search: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is! List) return [];
      print('🔍 MeirApiAdapter: Resources "$term" → ${data.length}');
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ MeirApiAdapter: Resources search error: $e');
      return [];
    }
  }

  int? _lessonId(Map<String, dynamic> lesson) {
    final id = lesson['lesson_post_id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  bool _matchesIntent(Map<String, dynamic> lesson, IntentResult intent) {
    final title = lesson['post_title']?.toString() ?? '';
    final teacher = lesson['rav_display_name']?.toString() ?? '';
    final series = lesson['series_facet_display_value']?.toString() ?? '';
    final combined = '$title $teacher $series'.toLowerCase();

    if (intent.teacher != null &&
        !_teacherMatches(teacher, intent.teacher!)) {
      return false;
    }
    if (intent.topic != null &&
        !_textContains(combined, intent.topic!)) {
      return false;
    }
    if (intent.book != null && !_textContains(combined, intent.book!)) {
      return false;
    }
    if (intent.parsha != null && !_matchesParsha(combined, intent.parsha!)) {
      return false;
    }
    if (intent.dafYomi != null && !_matchesDafYomi(combined, intent.dafYomi!)) {
      return false;
    }
    return true;
  }

  bool _matchesDafYomi(String haystack, String dafYomi) {
    final h = haystack.toLowerCase();
    if (dafYomi == 'היום' || dafYomi.contains('היום')) {
      return h.contains('דף יומי') || h.contains('דףיומי');
    }
    final name = dafYomi.toLowerCase();
    if (h.contains(name)) return true;
    final tractate = name.split(RegExp(r'[\s]+')).first;
    return tractate.length > 1 && h.contains(tractate);
  }

  bool _teacherMatches(String ravName, String intentTeacher) {
    final rav = ravName.toLowerCase();
    final needle = _cleanTerm(intentTeacher).toLowerCase();
    if (needle.isEmpty) return true;
    if (rav.contains(needle)) return true;

    for (final entry in _teacherAliases.entries) {
      final aliases = entry.value.map((a) => a.toLowerCase()).toList();
      final key = entry.key.toLowerCase();
      final intentMatchesAlias = aliases.any(
        (a) => needle.contains(a) || a.contains(needle) || needle == key,
      );
      if (!intentMatchesAlias) continue;
      if (rav.contains(key) || aliases.any((a) => rav.contains(a))) {
        return true;
      }
    }
    return false;
  }

  bool _textContains(String haystack, String needle) {
    final h = haystack.toLowerCase();
    final n = _cleanTerm(needle).toLowerCase();
    return n.isNotEmpty && h.contains(n);
  }

  bool _matchesParsha(String haystack, String parsha) {
    final h = haystack.toLowerCase();
    if (parsha == 'השבוע' || parsha.contains('השבוע')) {
      return h.contains('פרש') || h.contains('parasha');
    }
    final name = _cleanParshaName(parsha).toLowerCase();
    if (name.isEmpty) return true;
    return h.contains(name) ||
        h.contains('פרשת $name') ||
        h.contains('פרש $name');
  }

  SourceResult _toSourceResult(
    Map<String, dynamic> lesson,
    IntentResult intent, {
    int termHits = 1,
  }) {
    var score = _calculateScore(lesson, intent);
    score += (termHits - 1) * 0.15;
    return SourceResult(
      title: lesson['post_title']?.toString() ?? 'ללא כותרת',
      teacher: lesson['rav_display_name']?.toString(),
      source: name,
      score: score.clamp(0.0, 1.0),
      snippet: _createSnippet(lesson),
      metadata: {
        'lesson_post_id': lesson['lesson_post_id'],
        'rav_id': lesson['rav_id'],
        'series_post_id': lesson['series_post_id'],
        'vimeo_path': lesson['vimeo_path'],
        'mp3_path': lesson['mp3_path'],
        'mp4_path': lesson['mp4_path'],
        'post_date': lesson['post_date'],
        'series_name': lesson['series_facet_display_value'],
        'source_icon': 'assets/icon/meir.png',
      },
    );
  }

  Future<void> _searchNewLessons(
    IntentResult intent,
    List<SourceResult> results,
  ) async {
    try {
      final url = '${Globals.apiBaseUrl}/api/v3/resources/lessons/new20';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) return;

      final lessons =
          json.decode(utf8.decode(response.bodyBytes)) as List;
      for (final lesson in lessons) {
        final map = lesson as Map<String, dynamic>;
        if (!_matchesIntent(map, intent)) continue;
        results.add(_toSourceResult(map, intent));
        if (results.length >= intent.limit) break;
      }
    } catch (e) {
      print('❌ MeirApiAdapter: new20 error: $e');
    }
  }

  double _calculateScore(Map<String, dynamic> result, IntentResult intent) {
    double score = 0.4;

    final title = result['post_title']?.toString().toLowerCase() ?? '';
    final teacher = result['rav_display_name']?.toString() ?? '';
    final series =
        result['series_facet_display_value']?.toString().toLowerCase() ?? '';

    if (intent.topic != null) {
      final topic = _cleanTerm(intent.topic!).toLowerCase();
      if (title.contains(topic)) score += 0.25;
      if (series.contains(topic)) score += 0.15;
    }

    if (intent.teacher != null && _teacherMatches(teacher, intent.teacher!)) {
      score += 0.35;
    }

    final postDate = result['post_date']?.toString() ?? '';
    if (postDate.isNotEmpty) {
      try {
        final date = DateTime.parse(postDate);
        if (DateTime.now().difference(date).inDays < 30) score += 0.05;
      } catch (_) {}
    }

    return score.clamp(0.0, 1.0);
  }

  String _createSnippet(Map<String, dynamic> result) {
    final teacher = result['rav_display_name']?.toString() ?? '';
    final series = result['series_facet_display_value']?.toString() ?? '';
    final date = result['post_date']?.toString() ?? '';

    final parts = <String>[];
    if (teacher.isNotEmpty) parts.add('רב: $teacher');
    if (series.isNotEmpty) parts.add('סדרה: $series');
    if (date.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(date);
        parts.add(
          'תאריך: ${parsedDate.day}/${parsedDate.month}/${parsedDate.year}',
        );
      } catch (_) {}
    }
    return parts.join(' • ');
  }
}
