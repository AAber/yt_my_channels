import '../agent/models.dart';
import 'data_source.dart';
import 'david_api_client.dart';

class DavidApiAdapter implements DataSource {

  static const _hebrewStopWords = {
    'רב', 'הרב', 'רבי', 'ר\'', 'שיעור', 'שיעורים', 'על', 'של', 'מצא',
    'תן', 'לי',
    // do NOT add 'בני' or 'דוד' here — they are core search terms for this source
  };

  @override
  String get name => 'david_api';

  @override
  Future<List<SourceResult>> search(IntentResult intent) async {
    try {
      print('🔍 DavidApiAdapter: intent ${intent.toJson()}');

      // Skip if user explicitly requested a different source
      if (intent.source != null && intent.source != 'david_api') {
        print('🔍 DavidApiAdapter: source=${intent.source} ≠ david_api, skipping');
        return [];
      }

      final results = <SourceResult>[];
      final series = await DavidApiClient.getSeries();
      if (series.isEmpty) return [];

      final terms = _buildSearchTerms(intent);
      final seriesToScan = _seriesToScan(series, intent, terms);

      for (final seriesItem in seriesToScan) {
        final lessons = await DavidApiClient.getLessonsForSeries(
          seriesItem['slug']?.toString() ?? '',
        );
        for (final lesson in lessons) {
          if (!_matchesLessonIntent(lesson, seriesItem, intent, terms)) continue;

          results.add(_toSourceResult(lesson, seriesItem, intent, terms));
          if (results.length >= intent.limit * 2) break;
        }
        if (results.length >= intent.limit * 2) break;
      }

      results.sort((a, b) => b.score.compareTo(a.score));
      print('🔍 DavidApiAdapter: Returning ${results.length} results');
      return results.take(intent.limit).toList();
    } catch (e, stackTrace) {
      print('❌ DavidApiAdapter: $e\n$stackTrace');
      return [];
    }
  }

  bool _isDavidTeacher(String teacher) {
    // Only skip if user explicitly named a teacher from a different source.
    // "טורנר", "קשתיאל" etc. are valid Bnei David teachers — don't filter them out.
    // Block only explicit Meir-specific teachers.
    final t = teacher.toLowerCase();
    const meirOnly = {'מזרחי', 'mizrahi', 'פיירמן', 'fireman'};
    return !meirOnly.contains(t);
  }

  List<String> _buildSearchTerms(IntentResult intent) {
    final terms = <String>[];
    void add(String? v) {
      if (v == null || v.trim().isEmpty) return;
      final c = v.trim();
      if (!_hebrewStopWords.contains(c)) terms.add(c);
    }

    add(intent.topic);
    add(intent.teacher); // ← was missing: "טורנר", "קשתיאל" etc. must be searchable
    add(intent.book);
    _addParshaTerms(intent, terms);
    _addDafYomiTerms(intent, terms);
    return terms.toSet().toList();
  }

  void _addDafYomiTerms(IntentResult intent, List<String> terms) {
    final daf = intent.dafYomi?.trim();
    if (daf == null || daf.isEmpty) return;
    terms.add('דף יומי');
    if (daf == 'היום' || daf.contains('היום')) return;
    terms.add(daf);
    final tractate = daf.split(RegExp(r'[\s׳"\u05F3]+')).first;
    if (tractate.isNotEmpty) terms.add(tractate);
  }

  void _addParshaTerms(IntentResult intent, List<String> terms) {
    final parsha = intent.parsha?.trim();
    if (parsha == null || parsha.isEmpty) return;
    if (parsha == 'השבוע' || parsha.contains('השבוע')) {
      terms.addAll(['פרש', 'פרשת']);
      return;
    }
    var name = parsha.replaceAll(RegExp(r'^(פרשת|פרשה)\s+'), '').trim();
    if (name.isNotEmpty) {
      terms.add(name);
      terms.add('פרשת $name');
    }
  }

  List<Map<String, dynamic>> _seriesToScan(
    List<Map<String, dynamic>> all,
    IntentResult intent,
    List<String> terms,
  ) {
    if (terms.isEmpty) return all.take(5).toList();

    final matched = all.where((s) => _seriesMatchesTerms(s, terms)).toList();
    if (matched.isNotEmpty) return matched.take(8).toList();

    return all.take(12).toList();
  }

  bool _seriesMatchesTerms(Map<String, dynamic> series, List<String> terms) {
    final name = series['name']?.toString().toLowerCase() ?? '';
    return terms.any((t) => name.contains(t.toLowerCase()));
  }

  bool _matchesLessonIntent(
    Map<String, dynamic> lesson,
    Map<String, dynamic> series,
    IntentResult intent,
    List<String> terms,
  ) {
    final lessonName = lesson['name']?.toString() ?? '';
    final seriesName = series['name']?.toString() ?? '';
    final combined = '$lessonName $seriesName'.toLowerCase();

    if (terms.isEmpty) return true;

    if (intent.dafYomi != null &&
        (intent.dafYomi == 'היום' || intent.dafYomi!.contains('היום'))) {
      return combined.contains('דף') || terms.every((t) => combined.contains(t.toLowerCase()));
    }

    return terms.every((term) => combined.contains(term.toLowerCase()));
  }

  SourceResult _toSourceResult(
    Map<String, dynamic> lesson,
    Map<String, dynamic> series,
    IntentResult intent,
    List<String> terms,
  ) {
    return SourceResult(
      title: lesson['name']?.toString() ?? 'ללא כותרת',
      teacher: 'ישיבת בני דוד בעלי',
      source: name,
      score: _calculateScore(lesson, series, intent, terms),
      snippet: _createSnippet(lesson, series),
      metadata: {
        'lesson_id': lesson['id'],
        'series_id': lesson['series_id'],
        'lesson_slug': lesson['slug'],
        'series_slug': series['slug'],
        'series_name': series['name'],
        'mp4_url': lesson['mp4_url'],
        'mp3_url': lesson['mp3_url'],
        'lesson_number': lesson['lesson_number'],
        'url': lesson['url'],
        'source_icon': 'assets/icon/david.png',
      },
    );
  }

  double _calculateScore(
    Map<String, dynamic> lesson,
    Map<String, dynamic> series,
    IntentResult intent,
    List<String> terms,
  ) {
    double score = 0.4;
    final lessonName = lesson['name']?.toString().toLowerCase() ?? '';
    final seriesName = series['name']?.toString().toLowerCase() ?? '';

    for (final term in terms) {
      final t = term.toLowerCase();
      if (lessonName.contains(t)) score += 0.2;
      if (seriesName.contains(t)) score += 0.15;
    }

    if (lesson['mp4_url'] != null &&
        lesson['mp4_url'].toString().isNotEmpty) {
      score += 0.1;
    }
    return score.clamp(0.0, 1.0);
  }

  String _createSnippet(
    Map<String, dynamic> lesson,
    Map<String, dynamic> series,
  ) {
    final seriesName = series['name']?.toString() ?? '';
    final lessonNumber = lesson['lesson_number']?.toString() ?? '';
    final hasVideo =
        lesson['mp4_url'] != null && lesson['mp4_url'].toString().isNotEmpty;
    final hasAudio =
        lesson['mp3_url'] != null && lesson['mp3_url'].toString().isNotEmpty;

    final parts = <String>['מקור: ישיבת בני דוד בעלי'];
    if (seriesName.isNotEmpty) parts.add('סדרה: $seriesName');
    if (lessonNumber.isNotEmpty) parts.add('שיעור: $lessonNumber');
    final media = <String>[];
    if (hasVideo) media.add('וידאו');
    if (hasAudio) media.add('אודיו');
    if (media.isNotEmpty) parts.add('זמין: ${media.join(', ')}');
    return parts.join(' • ');
  }
}
