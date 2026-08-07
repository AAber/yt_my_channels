import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/lesson.dart';
import '../services/vimeo_service.dart';
import '../States/Keys.dart';

class BneiDavidScraper {
  static const _searchUrl =
      'https://bneidavid.org/%D7%93%D7%A3-%D7%94%D7%97%D7%99%D7%A4%D7%95%D7%A9/';

  /// Scrapes 12 lesson URLs from the search page, then resolves each to a
  /// Vimeo mp4 URL. Returns up to 12 [Lesson] objects with [mp4Url] set.
  static Future<List<Lesson>> fetchFeaturedLessons() async {
    final lessonUrls = await _scrapeLessonUrls();
    final lessons = <Lesson>[];

    for (final url in lessonUrls.take(12)) {
      try {
        final lesson = await _lessonFromUrl(url);
        if (lesson != null) lessons.add(lesson);
      } catch (e) {
        developer.log('SCRAPER: skipping $url — $e');
      }
    }
    return lessons;
  }

  static Future<List<String>> _scrapeLessonUrls() async {
    final response = await http.get(Uri.parse(_searchUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load search page: ${response.statusCode}');
    }
    final body = response.body;
    final pattern = RegExp(r'https://bneidavid\.org/lessons/[^"<>\s]+');
    final seen = <String>{};
    final urls = <String>[];
    for (final m in pattern.allMatches(body)) {
      final url = m.group(0)!;
      if (seen.add(url)) urls.add(url);
    }
    return urls;
  }

  static Future<Lesson?> _lessonFromUrl(String lessonUrl) async {
    final response = await http.get(Uri.parse(lessonUrl));
    if (response.statusCode != 200) return null;
    final body = response.body;

    // Extract Vimeo video ID from embed URL
    final vimeoPattern =
        RegExp(r'player\.vimeo\.com/video/(\d+)');
    final vimeoMatch = vimeoPattern.firstMatch(body);
    if (vimeoMatch == null) return null;
    final vimeoId = vimeoMatch.group(1)!;

    // Extract page title
    final titlePattern = RegExp(r'<title>([^<]+)</title>');
    final titleMatch = titlePattern.firstMatch(body);
    String title = titleMatch?.group(1) ?? lessonUrl.split('/').last;
    // Strip site name suffix
    if (title.contains(' - ')) title = title.split(' - ').first.trim();

    // Resolve mp4 URL via Vimeo API
    final mp4Url = await VimeoService.getProgressiveMp4(
      vimeoId,
      vimeoBearerToken,
    );

    if (mp4Url == null) return null;

    final slug = Uri.parse(lessonUrl).pathSegments.last;
    return Lesson(
      id: vimeoId,
      seriesId: '',
      name: title,
      url: lessonUrl,
      slug: slug,
      mp4Url: mp4Url,
      sourceId: 'bneidavid',
    );
  }
}
