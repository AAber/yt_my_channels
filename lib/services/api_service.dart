import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/series.dart';
import '../models/lesson.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Series>> getSeries() async {
    try {
      final url = ApiConfig.getSeriesUrl();
      developer.log('API_REQUEST: GET $url');
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      developer.log('API_RESPONSE: ${response.statusCode} for GET $url');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final seriesList = data['series'] as List;
        return seriesList.map((s) => Series.fromJson(s)).toList();
      } else {
        developer.log(
            'API_ERROR: Failed to load series - Status: ${response.statusCode}, Body: ${response.body}');
        throw ApiException('Failed to load series: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      developer.log('API_ERROR: Network error in getSeries: $e');
      throw ApiException('Network error: $e');
    }
  }

  Future<void> scanRecentLessons({int limit = 20}) async {
    try {
      final url = ApiConfig.getScanRecentUrl(limit: limit);
      developer.log('API_REQUEST: POST $url');
      final response = await _client.post(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 120));
      developer.log('API_RESPONSE: ${response.statusCode} for POST $url');
      if (response.statusCode != 200) {
        throw ApiException('scan_recent failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      developer.log('API_ERROR: Network error in scanRecentLessons: $e');
      throw ApiException('Network error: $e');
    }
  }

  Future<List<Lesson>> getRecentLessons({int limit = 20}) async {
    try {
      final url = ApiConfig.getRecentLessonsUrl(limit: limit);
      developer.log('API_REQUEST: GET $url');
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      developer.log('API_RESPONSE: ${response.statusCode} for GET $url');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lessonsList = data['lessons'] as List;
        return lessonsList.map((l) => Lesson.fromJson(l)).toList();
      } else {
        throw ApiException('Failed to load recent lessons: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      developer.log('API_ERROR: Network error in getRecentLessons: $e');
      throw ApiException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> getSeriesWithLessons(String slug) async {
    try {
      // Slug is already URL-encoded from the API, encode it again for the URL path
      final encodedSlug = Uri.encodeComponent(slug);
      final url = ApiConfig.getSeriesLessonsUrl(encodedSlug);
      developer.log('API_REQUEST: GET $url (original slug: $slug)');
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      developer.log('API_RESPONSE: ${response.statusCode} for GET $url');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        developer.log(
            'API_ERROR: Series not found - Slug: $slug, Status: ${response.statusCode}');
        throw ApiException('Series not found');
      } else {
        developer.log(
            'API_ERROR: Failed to load lessons - Slug: $slug, Status: ${response.statusCode}, Body: ${response.body}');
        throw ApiException('Failed to load lessons: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      developer
          .log('API_ERROR: Network error in getSeriesWithLessons($slug): $e');
      throw ApiException('Network error: $e');
    }
  }

  Future<Lesson> getLesson(String slug) async {
    try {
      // Slug is already URL-encoded from the API, encode it again for the URL path
      final encodedSlug = Uri.encodeComponent(slug);
      final url = ApiConfig.getLessonUrl(encodedSlug);
      developer.log('API_REQUEST: GET $url (original slug: $slug)');
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      developer.log('API_RESPONSE: ${response.statusCode} for GET $url');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Lesson.fromJson(data['lesson']);
      } else if (response.statusCode == 404) {
        developer.log(
            'API_ERROR: Lesson not found - Slug: $slug, Status: ${response.statusCode}');
        throw ApiException('Lesson not found');
      } else {
        developer.log(
            'API_ERROR: Failed to load lesson - Slug: $slug, Status: ${response.statusCode}, Body: ${response.body}');
        throw ApiException('Failed to load lesson: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      developer.log('API_ERROR: Network error in getLesson($slug): $e');
      throw ApiException('Network error: $e');
    }
  }

  Future<void> triggerScrape() async {
    try {
      final url = ApiConfig.getScrapeUrl();
      developer.log('API_REQUEST: POST $url');
      final response = await _client.post(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      developer.log('API_RESPONSE: ${response.statusCode} for POST $url');
      if (response.statusCode != 200) {
        developer.log(
            'API_ERROR: Failed to trigger scrape - Status: ${response.statusCode}, Body: ${response.body}');
        throw ApiException('Failed to trigger scrape: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      developer.log('API_ERROR: Network error in triggerScrape: $e');
      throw ApiException('Network error: $e');
    }
  }
}
