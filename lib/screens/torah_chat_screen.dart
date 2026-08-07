import 'package:flutter/material.dart';
import 'package:torah_ai_assistant/torah_ai_assistant.dart';
import '../models/lesson.dart';
import '../screens/player_screen.dart';
import '../screens/youtube_player_screen.dart';
import '../services/vimeo_service.dart';
import '../services/youtube_service.dart';
import '../States/Keys.dart';
import '../config/api_keys.dart';

class TorahChatScreen extends StatefulWidget {
  const TorahChatScreen({Key? key}) : super(key: key);

  @override
  State<TorahChatScreen> createState() => _TorahChatScreenState();
}

class _TorahChatScreenState extends State<TorahChatScreen> {
  late TorahAgent _agent;
  bool _isLoading = true;

  static const _youtubeChannels = [
    YouTubeChannel('UCQfTTiNEkZ3_HYr9S4zQB0g', 'עוד יוסף חי',       'assets/icon/yosef.png'),
    YouTubeChannel('UCJYMW0GZaanXsFnt5pnI6QA', 'חב"ד רמת אביב',     'assets/icon/aviv.png'),
    YouTubeChannel('UCXGUXEMhk3PaZxep7NVTM5A', 'ישיבת הסדר מעלות',  'assets/icon/maalot.png'),
    YouTubeChannel('UCdoHZjm2ku452xK4f5gRzZw', 'מעייני ישראל',      'assets/icon/mi.png'),
    YouTubeChannel('UCWdBoc1ZurwXJMOSq0eLx-A', 'ישיבת חולון',       'assets/icon/holon.png'),
    YouTubeChannel('UCkrqrlLmV0OBP9a3jMWTAcw', 'ממעל ממש',         'assets/icon/mimaal.png'),
    YouTubeChannel('UC4jSWBYE-jIllmJmsZC5xRQ', 'ישיבת שדרות',       'assets/icon/shderot.png'),
  ];

  @override
  void initState() {
    super.initState();
    _initAgent();
  }

  Future<void> _initAgent() async {
    _agent = TorahAgent(
      config: AgentConfig(groqApiKey: groqApiKey),
      sources: [
        MeirApiAdapter(),
        DavidApiAdapter(),
        YouTubeDataSource(
          apiKey: ApiKeys.youtubeApiKey,
          channels: _youtubeChannels,
        ),
      ],
    );
    await _agent.loadSession();
    setState(() => _isLoading = false);
  }

  Future<void> _onSourceTap(SourceResult result) async {
    final meta = result.metadata;
    debugPrint('CHAT_TAP 🔄 source=${result.source} title="${result.title}" meta=$meta');

    if (result.source == 'youtube') {
      final videoId = meta['video_id']?.toString() ?? '';
      final channelTitle = meta['channel_title']?.toString() ?? '';
      if (videoId.isEmpty) {
        debugPrint('🔴 CHAT_TAP youtube: NO video_id — meta=$meta');
        return;
      }
      debugPrint('▶️ CHAT_TAP youtube: videoId=$videoId channel=$channelTitle');
      final video = YouTubeVideo(
        id: videoId,
        title: result.title,
        description: '',
        thumbnailUrl: meta['thumbnail']?.toString() ?? '',
        publishedAt: DateTime.tryParse(
                meta['published_at']?.toString() ?? '') ??
            DateTime.now(),
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => YouTubePlayerScreen(
              video: video,
              channelTitle: channelTitle,
            ),
          ),
        );
      }
    } else if (result.source == 'meir_api') {
      await _openMeirLesson(meta, result.title);
    } else if (result.source == 'david_api') {
      // DavidApiAdapter metadata keys: lesson_id, lesson_slug, series_id,
      // mp4_url, mp3_url, url — does NOT include vimeo_url or name.
      final mp4 = meta['mp4_url']?.toString();
      final mp3 = meta['mp3_url']?.toString();
      debugPrint('🎬 CHAT_TAP david_api: mp4=$mp4 mp3=$mp3 title="${result.title}"');
      if ((mp4 == null || mp4.isEmpty) && (mp3 == null || mp3.isEmpty)) {
        debugPrint('🔴 CHAT_TAP david_api: NO MEDIA — mp4=$mp4 mp3=$mp3 meta=$meta');
        _showError('לא נמצא קישור מדיה לשיעור זה');
        return;
      }
      final lesson = Lesson(
        id: meta['lesson_id']?.toString() ?? '',
        seriesId: meta['series_id']?.toString() ?? '',
        name: result.title,
        url: meta['url']?.toString() ?? '',
        slug: meta['lesson_slug']?.toString() ?? '',
        mp4Url: mp4?.isNotEmpty == true ? mp4 : null,
        mp3Url: mp3?.isNotEmpty == true ? mp3 : null,
        sourceId: 'bneidavid',
      );
      debugPrint('✅ CHAT_TAP david_api: opening PlayerScreen mp4=${lesson.mp4Url} mp3=${lesson.mp3Url}');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerScreen(lesson: lesson)),
        );
      }
    } else {
      try {
        final lesson = Lesson.fromJson(meta);
        debugPrint('🎬 CHAT_TAP fallback: source=${result.source} mp4=${lesson.mp4Url} vimeo=${lesson.vimeoUrl} mp3=${lesson.mp3Url}');
        if (!lesson.hasVideo && !lesson.hasAudio) {
          debugPrint('🔴 CHAT_TAP fallback: NO MEDIA for "${result.title}" source=${result.source}');
        }
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(lesson: lesson)),
          );
        }
      } catch (e) {
        debugPrint('🔴 CHAT_TAP fallback FAILED: $e source=${result.source} meta=$meta');
        _showError('לא ניתן לפתוח את השיעור');
      }
    }
  }

  Future<void> _openMeirLesson(Map<String, dynamic> meta, String title) async {
    final vimeoId = meta['vimeo_path']?.toString() ?? '';
    final mp3 = meta['mp3_path']?.toString() ?? '';
    String? mp4Url;

    debugPrint('🎬 CHAT_TAP meir: vimeoId=$vimeoId mp3=$mp3 title="$title"');

    if (vimeoId.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('טוען קישור וידאו...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      mp4Url = await VimeoService.getProgressiveMp4(vimeoId, vimeoBearerToken);
      debugPrint(mp4Url != null
          ? '✅ CHAT_TAP meir: resolved mp4=$mp4Url'
          : '🔴 CHAT_TAP meir: Vimeo resolved NULL for vimeoId=$vimeoId');
    }

    if (!mounted) return;
    if (mp4Url == null && mp3.isEmpty) {
      debugPrint('🔴 CHAT_TAP meir: NO MEDIA — vimeoId=$vimeoId mp3=$mp3');
      _showError('לא נמצא קישור לשיעור זה');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          lesson: Lesson(
            id: meta['lesson_post_id']?.toString() ?? '',
            seriesId: meta['series_post_id']?.toString() ?? '',
            name: title,
            url: meta['shiur_url']?.toString() ?? '',
            slug: meta['lesson_post_id']?.toString() ?? '',
            mp4Url: mp4Url,
            mp3Url: mp3.isNotEmpty ? mp3 : null,
            sourceId: 'meir_api',
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _agent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('חברותא Ai')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange[600]!,
        title: const Text('חברותא Ai'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _agent.clearChat();
              setState(() {});
            },
          ),
        ],
      ),
      body: TorahChatWidget(
        agent: _agent,
        theme: ChatTheme.defaultTheme(context),
        onSourceTap: _onSourceTap,
      ),
    );
  }
}
