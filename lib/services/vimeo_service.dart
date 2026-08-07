import 'dart:convert';
import 'package:http/http.dart' as http;

class VimeoService {
  static const _apiBase = 'https://api.vimeo.com/videos';

  /// Returns a signed progressive mp4 URL for the given Vimeo video ID.
  /// Prefers 720p, falls back to best available quality.
  static Future<String?> getProgressiveMp4(
    String videoId,
    String bearerToken,
  ) async {
    final apiUrl = '$_apiBase/$videoId?fields=files';
    print('VIMEO_API: fetching $apiUrl');
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'bearer $bearerToken'},
      ).timeout(const Duration(seconds: 10));

      print('VIMEO_API: status=${response.statusCode} for videoId=$videoId');
      if (response.statusCode != 200) {
        print('VIMEO_API_FAIL: HTTP ${response.statusCode} body=${response.body}');
        return null;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map) {
        print('VIMEO_API_FAIL: response is not a Map (token may lack files access) for videoId=$videoId');
        return null;
      }
      final data = decoded as Map<String, dynamic>;
      final files = (data['files'] as List?)
          ?.whereType<Map>()
          .where((f) => f['type'] == 'video/mp4' && f['link'] != null)
          .toList();

      if (files == null || files.isEmpty) {
        print('VIMEO_API_FAIL: no mp4 files found for videoId=$videoId raw=${data.keys.toList()}');
        return null;
      }

      // Prefer 720p, then hd, then any
      final preferred = files.firstWhere(
        (f) => f['link'].toString().contains('720'),
        orElse: () => files.firstWhere(
          (f) => f['quality'] == 'hd',
          orElse: () => files.first,
        ),
      );

      final link = preferred['link']?.toString();
      print('VIMEO_API_SUCCESS: videoId=$videoId quality=${preferred['quality']} link=$link');
      return link;
    } catch (e, st) {
      print('VIMEO_API_ERROR: videoId=$videoId error=$e\n$st');
      return null;
    }
  }
}
