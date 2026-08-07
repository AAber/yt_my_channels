import 'dart:convert';
import 'package:http/http.dart' as http;
import '../agent/models.dart';
import 'data_source.dart';

class YouTubeChannel {
  final String id;
  final String title;
  final String iconAsset;
  const YouTubeChannel(this.id, this.title, this.iconAsset);
}

class YouTubeDataSource implements DataSource {
  final String apiKey;
  final List<YouTubeChannel> channels;

  static const _base = 'https://www.googleapis.com/youtube/v3';

  YouTubeDataSource({required this.apiKey, required this.channels});

  @override
  String get name => 'youtube';

  @override
  Future<List<SourceResult>> search(IntentResult intent) async {
    final terms = _buildTerms(intent);
    if (terms.isEmpty) return [];

    // If intent specifies a channel, only search that one
    final targetChannels = (intent.channel != null)
        ? channels.where((c) => c.id == intent.channel).toList()
        : channels;

    if (targetChannels.isEmpty) return [];

    final results = <SourceResult>[];

    for (final channel in targetChannels) {
      try {
        final videos = await _fetchChannelVideos(channel.id);
        for (final v in videos) {
          final combined =
              '${v['title']} ${v['description']}'.toLowerCase();
          if (terms.any((t) => combined.contains(t))) {
            results.add(_toResult(v, channel));
          }
        }
      } catch (_) {}
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(intent.limit).toList();
  }

  List<String> _buildTerms(IntentResult intent) {
    final terms = <String>[];
    void add(String? v) {
      if (v != null && v.trim().isNotEmpty) terms.add(v.trim().toLowerCase());
    }
    add(intent.topic);
    add(intent.teacher);
    add(intent.book);
    // For parsha: add both "פרשת" prefix and the parsha name as search terms
    final parsha = intent.parsha?.trim();
    if (parsha != null && parsha.isNotEmpty) {
      if (parsha == 'השבוע' || parsha.contains('השבוע')) {
        terms.add('פרשת'); // match any "פרשת X" title
      } else {
        add(parsha);
        terms.add('פרשת $parsha'.toLowerCase());
      }
    }
    return terms.toSet().toList();
  }

  Future<List<Map<String, dynamic>>> _fetchChannelVideos(
      String channelId) async {
    // Get uploads playlist ID
    final chRes = await http.get(
      Uri.parse(
          '$_base/channels?part=contentDetails&id=$channelId&key=$apiKey'),
    ).timeout(const Duration(seconds: 10));
    if (chRes.statusCode != 200) return [];

    final chData = json.decode(chRes.body);
    final playlistId = chData['items']?[0]?['contentDetails']
        ?['relatedPlaylists']?['uploads'] as String?;
    if (playlistId == null) return [];

    // Fetch videos
    final vRes = await http.get(
      Uri.parse(
          '$_base/playlistItems?part=snippet&playlistId=$playlistId&maxResults=200&key=$apiKey'),
    ).timeout(const Duration(seconds: 10));
    if (vRes.statusCode != 200) return [];

    final items = json.decode(vRes.body)['items'] as List? ?? [];
    return items.map((item) {
      final s = item['snippet'] as Map<String, dynamic>;
      return {
        'video_id': s['resourceId']?['videoId'] ?? '',
        'title': s['title'] ?? '',
        'description': s['description'] ?? '',
        'thumbnail': s['thumbnails']?['medium']?['url'] ?? '',
        'published_at': s['publishedAt'] ?? '',
      };
    }).toList();
  }

  SourceResult _toResult(Map<String, dynamic> v, YouTubeChannel channel) {
    return SourceResult(
      title: v['title'] as String,
      teacher: channel.title,
      source: name,
      score: 0.6,
      snippet: 'ערוץ: ${channel.title}',
      metadata: {
        'video_id': v['video_id'],
        'channel_title': channel.title,
        'channel_icon': channel.iconAsset,
        'thumbnail': v['thumbnail'],
        'published_at': v['published_at'],
      },
    );
  }
}
