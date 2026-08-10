import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../States/Keys.dart';
import '../services/saved_channels_service.dart';

class YouTubeVideo {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final DateTime publishedAt;

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.publishedAt,
  });

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] as Map<String, dynamic>;
    final resourceId = snippet['resourceId'] as Map<String, dynamic>;

    return YouTubeVideo(
      id: resourceId['videoId'] ?? '',
      title: snippet['title'] ?? '',
      description: snippet['description'] ?? '',
      thumbnailUrl: snippet['thumbnails']?['medium']?['url'] ?? '',
      publishedAt: DateTime.parse(
          snippet['publishedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class YouTubeService {
  // Use API key from secure config file
  static const String _apiKey = Keys.googleApiKey;
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  // Od Yosef Hai channel ID
  static const String odYosefHaiChannelId = 'UCQfTTiNEkZ3_HYr9S4zQB0g';

  /// Resolves a YouTube channel URL, handle (@name), or bare channel ID
  /// into a [SavedChannel]. Returns null if not found or API key missing.
  Future<SavedChannel?> fetchChannelInfo(String input) async {
    if (_apiKey.isEmpty || _apiKey.contains('YOUR_')) return null;
    final id = await _resolveChannelId(input.trim());
    if (id == null) return null;
    final url = '$_baseUrl/channels?part=snippet&id=$id&key=$_apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body);
    final items = data['items'] as List;
    if (items.isEmpty) return null;
    final snippet = items[0]['snippet'] as Map<String, dynamic>;
    final title = snippet['title'] as String? ?? id;
    final avatarUrl = (snippet['thumbnails']?['high']?['url'] ??
        snippet['thumbnails']?['default']?['url'] ?? '') as String;
    return SavedChannel(id: id, title: title, avatarUrl: avatarUrl);
  }

  /// Accepts: full channel URL, @handle, or bare UC... ID.
  Future<String?> _resolveChannelId(String input) async {
    // Already a channel ID
    if (RegExp(r'^UC[\w-]{22}$').hasMatch(input)) return input;

    // Extract from URL: /channel/UC...
    final channelMatch = RegExp(r'youtube\.com/channel/(UC[\w-]{22})').firstMatch(input);
    if (channelMatch != null) return channelMatch.group(1);

    // Extract handle: @name or youtube.com/@name
    final handleMatch = RegExp(r'@([\w.]+)').firstMatch(input);
    final handle = handleMatch?.group(1);
    if (handle != null) {
      final url = '$_baseUrl/channels?part=id&forHandle=@$handle&key=$_apiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        if (items.isNotEmpty) return items[0]['id'] as String;
      }
    }

    // Try as custom URL / username search
    final searchUrl = '$_baseUrl/search?part=snippet&type=channel&q=${Uri.encodeComponent(input)}&maxResults=1&key=$_apiKey';
    final searchResp = await http.get(Uri.parse(searchUrl));
    if (searchResp.statusCode == 200) {
      final data = json.decode(searchResp.body);
      final items = data['items'] as List;
      if (items.isNotEmpty) return items[0]['id']?['channelId'] as String?;
    }
    return null;
  }

  Future<String> _getUploadsPlaylistId(String channelId) async {
    try {
      if (_apiKey.isEmpty || _apiKey.contains('place')) {
        throw Exception('YouTube API key not configured. Add your key to lib/States/Keys.dart');
      }
      final url =
          '$_baseUrl/channels?part=contentDetails&id=$channelId&key=$_apiKey';
      developer.log('Fetching uploads playlist ID for channel: $channelId');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;

        if (items.isNotEmpty) {
          final uploadsPlaylistId =
              items[0]['contentDetails']['relatedPlaylists']['uploads'];
          developer.log('Uploads playlist ID: $uploadsPlaylistId');
          return uploadsPlaylistId;
        }
        throw Exception('Channel not found: $channelId');
      }

      if (response.statusCode == 400) {
        throw Exception('YouTube API key is invalid or not configured. Status: 400');
      }
      if (response.statusCode == 403) {
        throw Exception('YouTube API quota exceeded or key restricted. Status: 403');
      }

      throw Exception(
          'Failed to get uploads playlist ID: ${response.statusCode}');
    } catch (e) {
      developer.log('Error getting uploads playlist ID: $e');
      rethrow;
    }
  }

  Future<List<YouTubeVideo>> getChannelVideos({
    String? channelId,
    int maxResults = 50,
    String? pageToken,
  }) async {
    try {
      final targetChannelId = channelId ?? odYosefHaiChannelId;

      // First, get the uploads playlist ID
      final uploadsPlaylistId = await _getUploadsPlaylistId(targetChannelId);

      // Then fetch videos from that playlist
      final url =
          '$_baseUrl/playlistItems?part=snippet&playlistId=$uploadsPlaylistId&maxResults=$maxResults${pageToken != null ? '&pageToken=$pageToken' : ''}&key=$_apiKey';
      developer.log('Fetching videos from: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;

        final videos =
            items.map((item) => YouTubeVideo.fromJson(item)).toList();

        developer.log('Fetched ${videos.length} videos');
        return videos;
      } else {
        throw Exception(
            'Failed to load videos: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      developer.log('Error fetching YouTube videos: $e');
      rethrow;
    }
  }

  Future<List<YouTubeVideo>> searchVideos(String query,
      {int maxResults = 20}) async {
    try {
      final url =
          '$_baseUrl/search?part=snippet&channelId=$odYosefHaiChannelId&q=$query&type=video&maxResults=$maxResults&key=$_apiKey';
      developer.log('Searching videos: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;

        final videos = items.map((item) {
          final snippet = item['snippet'] as Map<String, dynamic>;
          final id = item['id'] as Map<String, dynamic>;

          return YouTubeVideo(
            id: id['videoId'] ?? '',
            title: snippet['title'] ?? '',
            description: snippet['description'] ?? '',
            thumbnailUrl: snippet['thumbnails']?['medium']?['url'] ?? '',
            publishedAt: DateTime.parse(
                snippet['publishedAt'] ?? DateTime.now().toIso8601String()),
          );
        }).toList();

        developer.log('Found ${videos.length} videos');
        return videos;
      } else {
        throw Exception('Failed to search videos: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error searching YouTube videos: $e');
      rethrow;
    }
  }
}
