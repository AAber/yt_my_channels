import 'package:hive/hive.dart';
import '../models/lesson.dart';
import '../services/youtube_service.dart';

class WatchEntry {
  final String type;
  final Lesson? lesson;
  final YouTubeVideo? video;
  final String? videoChannelTitle;
  final Duration position;
  final Duration total;
  final DateTime lastWatched;

  WatchEntry({
    required this.type,
    this.lesson,
    this.video,
    this.videoChannelTitle,
    required this.position,
    required this.total,
    required this.lastWatched,
  });

  String get title => lesson?.name ?? video?.title ?? '';
  double get progress =>
      total.inSeconds > 0 ? position.inSeconds / total.inSeconds : 0.0;
}

// Deep-converts Map<dynamic,dynamic> trees returned by Hive into Map<String,dynamic>
Map<String, dynamic> _deepConvert(Map src) {
  return src.map((k, v) {
    final value = v is Map ? _deepConvert(v) : v;
    return MapEntry(k.toString(), value);
  });
}

class WatchHistoryService {
  static const _boxName = 'watch_history';
  Box? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Future<void> saveLesson(
      Lesson lesson, Duration position, Duration total) async {
    await _box?.put('lesson_${lesson.slug}', {
      'type': 'lesson',
      'lesson': lesson.toJson(),
      'position': position.inSeconds,
      'total': total.inSeconds,
      'lastWatched': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> saveYouTube(
    YouTubeVideo video,
    String channelTitle,
    Duration position,
    Duration total,
  ) async {
    await _box?.put('yt_${video.id}', {
      'type': 'youtube',
      'videoId': video.id,
      'videoTitle': video.title,
      'videoDescription': video.description,
      'videoThumbnail': video.thumbnailUrl,
      'videoPublishedAt': video.publishedAt.millisecondsSinceEpoch,
      'channelTitle': channelTitle,
      'position': position.inSeconds,
      'total': total.inSeconds,
      'lastWatched': DateTime.now().millisecondsSinceEpoch,
    });
  }

  List<WatchEntry> getHistory() {
    if (_box == null) return [];
    final entries = <WatchEntry>[];
    for (final raw in _box!.values) {
      try {
        final map = _deepConvert(raw as Map);
        final type = map['type'] as String;
        final position = Duration(seconds: (map['position'] as num).toInt());
        final total = Duration(seconds: (map['total'] as num).toInt());
        final lastWatched = DateTime.fromMillisecondsSinceEpoch(
            (map['lastWatched'] as num).toInt());

        if (type == 'lesson') {
          entries.add(WatchEntry(
            type: 'lesson',
            lesson: Lesson.fromJson(_deepConvert(map['lesson'] as Map)),
            position: position,
            total: total,
            lastWatched: lastWatched,
          ));
        } else if (type == 'youtube') {
          entries.add(WatchEntry(
            type: 'youtube',
            video: YouTubeVideo(
              id: map['videoId'] as String,
              title: map['videoTitle'] as String,
              description: map['videoDescription'] as String,
              thumbnailUrl: map['videoThumbnail'] as String,
              publishedAt: DateTime.fromMillisecondsSinceEpoch(
                  (map['videoPublishedAt'] as num).toInt()),
            ),
            videoChannelTitle: map['channelTitle'] as String?,
            position: position,
            total: total,
            lastWatched: lastWatched,
          ));
        }
      } catch (_) {}
    }
    entries.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    return entries;
  }

  Duration? getLessonPosition(String slug) {
    final raw = _box?.get('lesson_$slug');
    if (raw == null) return null;
    return Duration(seconds: (raw['position'] as num).toInt());
  }

  Duration? getYouTubePosition(String videoId) {
    final raw = _box?.get('yt_$videoId');
    if (raw == null) return null;
    return Duration(seconds: (raw['position'] as num).toInt());
  }
}
