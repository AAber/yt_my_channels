import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

/// HTTP client for the Bnei David API — mirrors israel/lib/services/api_service.dart
class DavidApiClient {
  static const String baseUrl = 'https://david.isaac770.live/api/v1';

  /// Slugs from the API are already percent-encoded; encode again for the path.
  static String _encodedSlug(String slug) => Uri.encodeComponent(slug);

  static Future<List<Map<String, dynamic>>> getSeries() async {
    final url = '$baseUrl/series';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        developer.log('🔴 DavidApiClient getSeries: HTTP ${response.statusCode} $url');
        return [];
      }
      final data = json.decode(utf8.decode(response.bodyBytes));
      final list = data['series'] as List? ?? [];
      developer.log('✅ DavidApiClient getSeries: ${list.length} series');
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('🔴 DavidApiClient getSeries ERROR: $e url=$url');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getSeriesWithLessons(String slug) async {
    if (slug.isEmpty) return null;
    final url = '$baseUrl/series/${_encodedSlug(slug)}';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        developer.log('🔴 DavidApiClient getSeriesWithLessons: HTTP ${response.statusCode} slug=$slug');
        return null;
      }
      return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      developer.log('🔴 DavidApiClient getSeriesWithLessons ERROR: $e slug=$slug');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getLessonsForSeries(
    String seriesSlug,
  ) async {
    final data = await getSeriesWithLessons(seriesSlug);
    if (data == null) return [];
    final lessons = data['lessons'] as List? ?? [];
    developer.log('📚 DavidApiClient getLessonsForSeries: ${lessons.length} lessons for slug=$seriesSlug');
    // Log media availability
    int withMp4 = 0, withMp3 = 0, noMedia = 0;
    for (final l in lessons) {
      final hasMp4 = (l['mp4_url']?.toString() ?? '').isNotEmpty;
      final hasMp3 = (l['mp3_url']?.toString() ?? '').isNotEmpty;
      if (hasMp4) withMp4++;
      else if (hasMp3) withMp3++;
      else noMedia++;
    }
    if (noMedia > 0) {
      developer.log('⚠️  DavidApiClient: slug=$seriesSlug — mp4=$withMp4 mp3=$withMp3 🔴noMedia=$noMedia');
    }
    return lessons.cast<Map<String, dynamic>>();
  }

  /// Full lesson record including mp4_url / mp3_url from GET /api/v1/lessons/{slug}
  static Future<Map<String, dynamic>?> getLesson(String lessonSlug) async {
    if (lessonSlug.isEmpty) return null;
    final url = '$baseUrl/lessons/${_encodedSlug(lessonSlug)}';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        developer.log('🔴 DavidApiClient getLesson: HTTP ${response.statusCode} slug=$lessonSlug');
        return null;
      }
      final data = json.decode(utf8.decode(response.bodyBytes));
      final lesson = data['lesson'] as Map<String, dynamic>?;
      if (lesson != null) {
        final hasMp4 = (lesson['mp4_url']?.toString() ?? '').isNotEmpty;
        final hasMp3 = (lesson['mp3_url']?.toString() ?? '').isNotEmpty;
        if (!hasMp4 && !hasMp3) {
          developer.log('🔴 DavidApiClient getLesson: NO MEDIA for slug=$lessonSlug');
        }
      }
      return lesson;
    } catch (e) {
      developer.log('🔴 DavidApiClient getLesson ERROR: $e slug=$lessonSlug');
      return null;
    }
  }
}
