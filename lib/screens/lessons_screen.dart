import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:video_player/video_player.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../l10n/app_localizations.dart';
import '../models/series.dart';
import '../models/lesson.dart';
import '../services/api_service.dart';
import '../services/video_thumbnail_cache.dart';
import 'player_screen.dart';
import 'home_screen.dart' show VimeoPlayerScreen;

enum _LessonsSort { number, numberDesc, name }

class LessonsScreen extends StatefulWidget {
  final Series series;

  const LessonsScreen({super.key, required this.series});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Lesson> _lessons = [];
  List<Lesson> _filteredLessons = [];
  bool _isLoading = true;
  String? _error;
  _LessonsSort _sort = _LessonsSort.number;

  @override
  void initState() {
    super.initState();
    _loadLessons();
    _searchController.addListener(_filterLessons);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySort(List<Lesson> list) {
    if (_sort == _LessonsSort.number) {
      list.sort((a, b) {
        final an = a.lessonNumber ?? 999999;
        final bn = b.lessonNumber ?? 999999;
        return an != bn ? an.compareTo(bn) : a.name.compareTo(b.name);
      });
    } else if (_sort == _LessonsSort.numberDesc) {
      list.sort((a, b) {
        final an = a.lessonNumber ?? -1;
        final bn = b.lessonNumber ?? -1;
        return an != bn ? bn.compareTo(an) : a.name.compareTo(b.name);
      });
    } else {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  void _filterLessons() {
    final query = _searchController.text.toLowerCase();
    final filtered = query.isEmpty
        ? List<Lesson>.from(_lessons)
        : _lessons.where((l) => l.name.toLowerCase().contains(query)).toList();
    _applySort(filtered);
    setState(() => _filteredLessons = filtered);
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getSeriesWithLessons(widget.series.slug);
      
      final lessonsList = data['lessons'] as List;
      final lessons = lessonsList
          .map((l) => Lesson.fromJson(l))
          .where((l) => l.hasVideo || l.hasAudio)
          .toList();
      _applySort(lessons);

      setState(() {
        _lessons = lessons;
        _filteredLessons = List<Lesson>.from(lessons);
        _isLoading = false;
      });
    } catch (e) {
      developer.log('CRITICAL_ERROR: Failed to load lessons for series ${widget.series.slug}: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showSortMenu(BuildContext anchorContext) async {
    final button = anchorContext.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(anchorContext).overlay!.context.findRenderObject()!
            as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<_LessonsSort>(
      context: anchorContext,
      position: position,
      items: [
        PopupMenuItem(
          value: _LessonsSort.number,
          child: Row(children: [
            Icon(Icons.check,
                size: 18,
                color: _sort == _LessonsSort.number
                    ? null
                    : Colors.transparent),
            const SizedBox(width: 8),
            const Text('מספר שיעור ↑'),
          ]),
        ),
        PopupMenuItem(
          value: _LessonsSort.numberDesc,
          child: Row(children: [
            Icon(Icons.check,
                size: 18,
                color: _sort == _LessonsSort.numberDesc
                    ? null
                    : Colors.transparent),
            const SizedBox(width: 8),
            const Text('מספר שיעור ↓'),
          ]),
        ),
        PopupMenuItem(
          value: _LessonsSort.name,
          child: Row(children: [
            Icon(Icons.check,
                size: 18,
                color: _sort == _LessonsSort.name
                    ? null
                    : Colors.transparent),
            const SizedBox(width: 8),
            const Text('א-ב / A-Z'),
          ]),
        ),
      ],
    );
    if (selected != null && mounted) {
      setState(() => _sort = selected);
      _filterLessons();
    }
  }

  Widget _sortIconButton() {
    return Builder(
      builder: (btnContext) => IconButton(
        icon: const Icon(Icons.sort),
        tooltip: 'מיון',
        onPressed: () => _showSortMenu(btnContext),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHebrew = Localizations.localeOf(context).languageCode == 'he';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.series.name),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: isHebrew ? _sortIconButton() : const BackButton(),
        actions: isHebrew ? [const BackButton()] : [_sortIconButton()],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${l10n.error}: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLessons,
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLessons,
      child: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.translate('search_lessons'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          // Results count
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${_filteredLessons.length} ${l10n.translate('results')}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),
          
          // List
          Expanded(
            child: _filteredLessons.isEmpty
                ? Center(
                    child: Text(
                      l10n.translate('no_results'),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredLessons.length,
                    itemBuilder: (context, index) {
                      final lesson = _filteredLessons[index];
                      return _buildLessonTile(lesson);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonTile(Lesson lesson) {
    // Vimeo-only lesson → full preview card with webview
    if (lesson.mp4Url == null && lesson.vimeoUrl != null) {
      return _VimeoLessonCard(lesson: lesson);
    }
    
    // MP4 or audio lesson → compact ListTile
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: SizedBox(
          width: 72,
          height: 48,
          child: lesson.hasMp4
              ? _LessonThumb(mp4Url: lesson.mp4Url!, thumbnailUrl: lesson.thumbnailUrl)
              : lesson.thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(lesson.thumbnailUrl!, fit: BoxFit.cover),
                    )
                  : lesson.sourceId == 'bneidavid'
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            'assets/icon/david.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.play_circle_fill,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                        )
                      : const Icon(Icons.play_circle_fill, color: Colors.blue, size: 40),
        ),
        title: Text(lesson.name),
        subtitle: lesson.lessonNumber != null
            ? Text('${l10n.lesson} ${lesson.lessonNumber}')
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lesson.hasVideo)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.videocam, color: Colors.blue),
              ),
            if (lesson.hasAudio)
              const Icon(Icons.audiotrack, color: Colors.green),
          ],
        ),
        onTap: () {
          developer.log(
            'LESSON_TAP: "${lesson.name}" mp4=${lesson.mp4Url ?? "null"} mp3=${lesson.mp3Url ?? "null"} vimeo=${lesson.vimeoUrl ?? "null"} source=${lesson.sourceId}',
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(lesson: lesson),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _VimeoLessonCard extends StatefulWidget {
  final Lesson lesson;
  const _VimeoLessonCard({required this.lesson});

  @override
  State<_VimeoLessonCard> createState() => _VimeoLessonCardState();
}

class _VimeoLessonCardState extends State<_VimeoLessonCard> {

  String? get _vimeoEmbedUrl {
    final v = widget.lesson.vimeoUrl;
    if (v == null) return null;
    final m = RegExp(r'vimeo\.com/(\d+)').firstMatch(v);
    if (m == null) return null;
    return 'https://player.vimeo.com/video/${m.group(1)}?autoplay=1';
  }

  @override
  Widget build(BuildContext context) {
    final embedUrl = _vimeoEmbedUrl;
    developer.log('LESSONS_VIMEO_CARD: "${widget.lesson.name}" vimeoUrl=${widget.lesson.vimeoUrl ?? "null"} embedUrl=${embedUrl ?? "null"}');

    if (embedUrl == null) {
      developer.log('LESSONS_VIMEO_CARD_ERROR: no embed URL for "${widget.lesson.name}" — vimeoUrl=${widget.lesson.vimeoUrl}');
      return const SizedBox.shrink();
    }

    final previewUrl = embedUrl.replaceFirst('autoplay=1', 'autoplay=0');
    developer.log('LESSONS_VIMEO_CARD: previewUrl=$previewUrl fullscreenUrl=$embedUrl');

    return GestureDetector(
      onTap: () {
        developer.log('LESSONS_VIMEO_CARD_TAP: opening VimeoPlayerScreen for "${widget.lesson.name}" embedUrl=$embedUrl');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VimeoPlayerScreen(
            title: widget.lesson.name,
            embedUrl: embedUrl,
          )),
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
                    url: WebUri(previewUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    mediaPlaybackRequiresUserGesture: true,
                    allowsInlineMediaPlayback: true,
                    javaScriptEnabled: true,
                    transparentBackground: true,
                    disableContextMenu: true,
                    supportZoom: false,
                    useHybridComposition: true,
                  ),
                  onWebViewCreated: (controller) {
                    developer.log('LESSONS_VIMEO_CARD_WEBVIEW_CREATED: "${widget.lesson.name}"');
                  },
                  onLoadStop: (controller, url) {
                    developer.log('LESSONS_VIMEO_CARD_LOAD_STOP: "${widget.lesson.name}" url=$url');
                  },
                  onReceivedError: (controller, request, error) {
                    developer.log('LESSONS_VIMEO_CARD_ERROR: "${widget.lesson.name}" url=${request.url} error=${error.description}');
                  },
                  onConsoleMessage: (controller, msg) {
                    developer.log('LESSONS_VIMEO_CARD_CONSOLE: "${widget.lesson.name}" [${msg.messageLevel}] ${msg.message}');
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
                          widget.lesson.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fullscreen),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          developer.log('LESSONS_VIMEO_CARD_FULLSCREEN: "${widget.lesson.name}" embedUrl=$embedUrl');
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => VimeoPlayerScreen(
                              title: widget.lesson.name,
                              embedUrl: embedUrl,
                            )),
                          );
                        },
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
}

// ---------------------------------------------------------------------------

class _LessonThumb extends StatefulWidget {
  final String mp4Url;
  final String? thumbnailUrl;
  const _LessonThumb({required this.mp4Url, this.thumbnailUrl});

  @override
  State<_LessonThumb> createState() => _LessonThumbState();
}

class _LessonThumbState extends State<_LessonThumb> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ctrl = await VideoThumbnailCache.instance.get(widget.mp4Url);
    if (mounted && ctrl != null) {
      setState(() { _ctrl = ctrl; _ready = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: _ready && _ctrl != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(_ctrl!),
                const Center(
                  child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 24),
                ),
              ],
            )
          : widget.thumbnailUrl != null
              ? Image.network(widget.thumbnailUrl!, fit: BoxFit.cover)
              : Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 1.5),
                  ),
                ),
    );
  }
}