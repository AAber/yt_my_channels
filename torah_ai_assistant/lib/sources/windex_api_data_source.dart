import 'dart:convert';
import 'package:http/http.dart' as http;
import '../agent/models.dart';
import 'data_source.dart';

class WindexApiDataSource implements DataSource {
  final String apiEndpoint;
  final List<String> hebrewStopWords = [
    'של', 'טוב', 'ו', 'כי', 'את', 'או', 'ה', 'זה', 'זו', 'אלה', 'אלו',
    'מה', 'מי', 'איך', 'איפה', 'מתי', 'למה', 'כמו', 'גם', 'רק', 'עוד',
    'כל', 'כלם', 'כלום', 'שום', 'אף', 'אחד', 'אחת', 'שניים', 'שתיים',
    'הרבה', 'מעט', 'יותר', 'פחות', 'כך', 'ככה', 'אז', 'אחרי', 'לפני',
    'על', 'ב', 'ל', 'מ', 'מן', 'אל', 'עד', 'מאז', 'עכשיו', 'היום',
    'אתמול', 'מחר', 'שבוע', 'חודש', 'שנה', 'פעם', 'פעמים', 'לפעמים',
    'תמיד', 'אף פעם', 'בטח', 'אולי', 'בעצם', 'אבל', 'אם', 'כדי',
  ];

  WindexApiDataSource({required this.apiEndpoint});

  @override
  String get name => 'windex';

  @override
  Future<List<SourceResult>> search(IntentResult intent) async {
    try {
      // Build search query from intent
      final searchTerms = <String>[];
      
      if (intent.topic != null) searchTerms.add(intent.topic!);
      if (intent.teacher != null) searchTerms.add(intent.teacher!);
      if (intent.book != null) searchTerms.add(intent.book!);
      if (intent.parsha != null) searchTerms.add(intent.parsha!);
      
      if (searchTerms.isEmpty) return [];
      
      // Filter out Hebrew stop words
      final filteredTerms = searchTerms
          .where((term) => !hebrewStopWords.contains(term))
          .toList();
      
      if (filteredTerms.isEmpty) return [];
      
      final allResults = <Map<String, dynamic>>[];
      
      // Search each term and collect results
      for (final term in filteredTerms.take(4)) {
        final results = await _searchWord(term);
        allResults.addAll(results);
      }
      
      // Remove duplicates and convert to SourceResult
      final uniqueResults = <String, Map<String, dynamic>>{};
      for (final result in allResults) {
        final id = result['lesson_post_id']?.toString() ?? 
                  result['ID']?.toString() ?? 
                  result['id']?.toString() ?? '';
        
        if (id.isNotEmpty && result['post_title'] != null) {
          uniqueResults[id] = result;
        }
      }
      
      // Convert to SourceResult and sort by date
      final sourceResults = uniqueResults.values.map((result) {
        return SourceResult(
          title: result['post_title']?.toString() ?? 'ללא כותרת',
          teacher: result['rav_display_name']?.toString(),
          source: name,
          score: _calculateScore(result, intent),
          snippet: _generateSnippet(result),
          metadata: result,
        );
      }).toList();
      
      // Sort by score and take top results
      sourceResults.sort((a, b) => b.score.compareTo(a.score));
      return sourceResults.take(intent.limit).toList();
      
    } catch (e) {
      print('Error in WindexApiDataSource.search: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchWord(String word) async {
    try {
      final hebrewOnlyWord = _filterHebrewOnly(word);
      if (hebrewOnlyWord.isEmpty) return [];
      
      final encodedQuery = Uri.encodeComponent(hebrewOnlyWord);
      final url = '$apiEndpoint?q=$encodedQuery';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);

        final results = data['results'] ??
            data['data'] ??
            data['lessons'] ??
            (data is List ? data : []);

        return results is List ? List<Map<String, dynamic>>.from(results) : [];
      }
    } catch (e) {
      print('Error searching for word "$word": $e');
    }
    return [];
  }

  String _filterHebrewOnly(String text) {
    final hebrewRegex = RegExp(r'[\u05D0-\u05EA\s]+');
    final matches = hebrewRegex.allMatches(text);
    return matches.map((match) => match.group(0)!).join(' ').trim();
  }

  double _calculateScore(Map<String, dynamic> result, IntentResult intent) {
    double score = 0.5; // Base score
    
    final title = result['post_title']?.toString()?.toLowerCase() ?? '';
    final teacher = result['rav_display_name']?.toString()?.toLowerCase() ?? '';
    
    // Boost score for matching teacher
    if (intent.teacher != null && teacher.contains(intent.teacher!.toLowerCase())) {
      score += 0.3;
    }
    
    // Boost score for matching topic in title
    if (intent.topic != null && title.contains(intent.topic!.toLowerCase())) {
      score += 0.2;
    }
    
    // Consider duration if specified
    if (intent.durationMax != null) {
      final duration = result['duration_seconds']?.toString();
      if (duration != null) {
        final durationSec = int.tryParse(duration) ?? 0;
        final maxDurationSec = intent.durationMax! * 60;
        if (durationSec <= maxDurationSec) {
          score += 0.1;
        }
      }
    }
    
    return score.clamp(0.0, 1.0);
  }

  String _generateSnippet(Map<String, dynamic> result) {
    final title = result['post_title']?.toString() ?? '';
    final teacher = result['rav_display_name']?.toString() ?? '';
    
    if (teacher.isNotEmpty) {
      return '$title - $teacher';
    }
    return title;
  }
}