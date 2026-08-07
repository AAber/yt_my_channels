import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language_provider.dart';
import '../models/lesson.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/video_thumbnail_cache.dart';
import 'series_list_screen.dart';
import 'player_screen.dart';
import 'source_selection_screen.dart';

const _tag = 'FEED';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final LocalStorageService _localStorage = LocalStorageService();
  List<Lesson> _lessons = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    developer.log('$_tag: initState', name: _tag);
    _init();
  }

  Future<void> _init() async {
    await _localStorage.init();
    await _loadLessons(forceRefresh: false);
  }

  Future<void> _loadLessons({bool forceRefresh = false}) async {
    developer.log('$_tag: _loadLessons forceRefresh=$forceRefresh', name: _tag);
    setState(() { _isLoading = true; _error = null; });

    if (!forceRefresh) {
      final cached = _localStorage.getCachedFeedLessons();
      if (cached != null && cached.isNotEmpty) {
        developer.log('$_tag: cache HIT — ${cached.length} lessons', name: _tag);
        _logLessons(cached);
        setState(() { _lessons = cached; _isLoading = false; });
        return;
      }
      developer.log('$_tag: cache MISS', name: _tag);
    }

    try {
      final lessons = await _apiService.getRecentLessons(limit: 20);
      developer.log('$_tag: API returned ${lessons.length} lessons', name: _tag);
      _logLessons(lessons);

      VideoThumbnailCache.instance.evictAll();
      await _localStorage.cacheFeedLessons(lessons);
      setState(() { _lessons = lessons; _isLoading = false; });
    } catch (e, st) {
      developer.log('$_tag: API ERROR $e', name: _tag, error: e, stackTrace: st);
      final stale = _localStorage.getCachedFeedLessons();
      setState(() {
        _lessons = stale ?? [];
        _error = stale != null ? null : e.toString();
        _isLoading = false;
      });
    }
  }

  void _logLessons(List<Lesson> lessons) {
    for (var i = 0; i < lessons.length; i++) {
      final l = lessons[i];
      developer.log(
        '$_tag: [$i] "${l.name}" mp4=${l.mp4Url ?? "null"} vimeo=${l.vimeoUrl ?? "null"}',
        name: _tag,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isHebrew = languageProvider.locale.languageCode == 'he';

    return Scaffold(
      appBar: AppBar(
        title: const Text('בני דוד'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: isHebrew
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _navigateToSourceSelection(context),
              ),
        actions: [
          if (isHebrew)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _navigateToSourceSelection(context),
            ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => languageProvider.toggleLanguage(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  void _navigateToSourceSelection(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SourceSelectionScreen()),
      (route) => false,
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${l10n.error}: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadLessons(forceRefresh: true),
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadLessons(forceRefresh: true),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SeriesListScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,),
            child: Text(l10n.allSeries, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.newLessons,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          ..._lessons.map((lesson) => _VideoPreviewCard(lesson: lesson)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _VideoPreviewCard extends StatelessWidget {
  final Lesson lesson;
  const _VideoPreviewCard({required this.lesson});

  String? get _vimeoEmbedUrl {
    final v = lesson.vimeoUrl;
    if (v == null) return null;
    final m = RegExp(r'vimeo\.com/(\d+)').firstMatch(v);
    if (m == null) return null;
    return 'https://player.vimeo.com/video/${m.group(1)}?autoplay=1';
  }

  @override
  Widget build(BuildContext context) {
    // Vimeo-only lesson → full card with inline webview preview, opens fullscreen on tap
    if (lesson.mp4Url == null && _vimeoEmbedUrl != null) {
      return GestureDetector(
        onTap: () {
          developer.log('$_tag: opening vimeo webview for "${lesson.name}" url=$_vimeoEmbedUrl');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VimeoPlayerScreen(
                title: lesson.name,
                embedUrl: _vimeoEmbedUrl!,
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / (9 * 1.3),
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(_vimeoEmbedUrl!.replaceFirst('autoplay=1', 'autoplay=0')),
                    ),
                    initialSettings: InAppWebViewSettings(
                      mediaPlaybackRequiresUserGesture: true,
                      allowsInlineMediaPlayback: true,
                      javaScriptEnabled: true,
                      transparentBackground: true,
                      disableContextMenu: true,
                      supportZoom: false,
                    ),
                    onLoadStop: (controller, url) async {
                      await controller.evaluateJavascript(source: '''
                        var speedBtn = document.createElement('button');
                        speedBtn.innerText = '1x';
                        speedBtn.style = 'position:fixed;bottom:60px;right:12px;z-index:9999;'
                                       + 'background:#000;color:#fff;border:none;'
                                       + 'padding:6px 10px;border-radius:4px;font-size:14px;cursor:pointer;';
                        var speeds = [0.5, 0.75, 1, 1.25, 1.5, 2];
                        var idx = 2;
                        speedBtn.onclick = function() {
                          idx = (idx + 1) % speeds.length;
                          var v = document.querySelector('video');
                          if (v) v.playbackRate = speeds[idx];
                          speedBtn.innerText = speeds[idx] + 'x';
                        };
                        document.body.appendChild(speedBtn);
                      ''');
                    },
                  ),
                ),
                ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lesson.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.fullscreen),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VimeoPlayerScreen(
                                title: lesson.name,
                                embedUrl: _vimeoEmbedUrl!,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Direct mp4 lesson → full preview card (unchanged)
    return _Mp4PreviewCard(lesson: lesson);
  }
}

// ---------------------------------------------------------------------------

class _Mp4PreviewCard extends StatefulWidget {
  final Lesson lesson;
  const _Mp4PreviewCard({required this.lesson});

  @override
  State<_Mp4PreviewCard> createState() => _Mp4PreviewCardState();
}

class _Mp4PreviewCardState extends State<_Mp4PreviewCard> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.lesson.mp4Url != null) _loadThumb();
  }

  Future<void> _loadThumb() async {
    final ctrl = await VideoThumbnailCache.instance.get(widget.lesson.mp4Url!);
    if (mounted && ctrl != null) setState(() { _ctrl = ctrl; _ready = true; });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(lesson: widget.lesson)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_ready && _ctrl != null)
                      VideoPlayer(_ctrl!)
                    else if (widget.lesson.thumbnailUrl != null)
                      Image.network(widget.lesson.thumbnailUrl!, fit: BoxFit.cover)
                    else
                      Container(color: Colors.grey[900],
                        child: const Center(child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2))),
                    const Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(
                    widget.lesson.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------

class VimeoPlayerScreen extends StatefulWidget {
  final String title;
  final String embedUrl;
  const VimeoPlayerScreen({super.key, required this.title, required this.embedUrl});

  @override
  State<VimeoPlayerScreen> createState() => _VimeoPlayerScreenState();
}

class _VimeoPlayerScreenState extends State<VimeoPlayerScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extract the Vimeo video ID from the embed URL
    final uri = Uri.tryParse(widget.embedUrl);
    final videoId = uri?.pathSegments.firstWhere(
      (s) => RegExp(r'^\d+$').hasMatch(s),
      orElse: () => '',
    ) ?? '';

    final html = '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
* { margin:0; padding:0; box-sizing:border-box; }
html, body { width:100%; height:100%; background:#000; overflow:hidden; }
#player { position:fixed; top:0; left:0; width:100%; height:100%; border:none; }
</style>
</head>
<body>
<iframe id="player" src="https://player.vimeo.com/video/$videoId?autoplay=1&api=1" 
  allow="autoplay; fullscreen; picture-in-picture" allowfullscreen></iframe>
</body>
</html>''';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          InAppWebView(
            initialData: InAppWebViewInitialData(data: html, mimeType: 'text/html'),
            initialSettings: InAppWebViewSettings(
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              javaScriptEnabled: true,
              useHybridComposition: true,
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
