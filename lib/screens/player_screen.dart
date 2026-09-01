import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language_provider.dart';
import '../models/lesson.dart';
import '../services/audio_player_service.dart';
import '../services/lesson_media_resolver.dart';
import '../services/watch_history_service.dart';
import '../services/download_service.dart';

class PlayerScreen extends StatefulWidget {
  final Lesson lesson;
  final Duration? resumePosition;

  const PlayerScreen({super.key, required this.lesson, this.resumePosition});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  InAppWebViewController? _vimeoWebCtrl;

  late Lesson _lesson;
  final LessonMediaResolver _mediaResolver = LessonMediaResolver();
  
  bool _isVideoInitialized = false;
  bool _isAudioInitialized = false;
  bool _isPlaying = false;
  bool _showVideo = true;
  bool _isLoadingMedia = true;
  String? _mediaError;
  double _playbackSpeed = 1.0;
  bool _isFullScreen = false;
  Timer? _saveTimer;
  StreamSubscription<PlayerState>? _audioSub;
  final WatchHistoryService _historyService = WatchHistoryService();

  // Download state
  double? _mp4DownloadProgress;   // null=idle, 0-1=downloading, -1=done
  double? _mp3DownloadProgress;
  bool _mp4Downloaded = false;
  bool _mp3Downloaded = false;
  
  // Available playback speeds
  final List<double> _availableSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    _historyService.init().then((_) => _initializePlayers());
    _checkDownloaded();
    WakelockPlus.enable(); // Prevent device lock during video playback
  }

  Future<void> _checkDownloaded() async {
    final mp4 = await DownloadService.localPath(widget.lesson.name, DownloadType.mp4);
    final mp3 = await DownloadService.localPath(widget.lesson.name, DownloadType.mp3);
    if (mounted) setState(() {
      _mp4Downloaded = mp4 != null;
      _mp3Downloaded = mp3 != null;
    });
  }

  Future<void> _download(DownloadType type) async {
    final url = type == DownloadType.mp4 ? _lesson.mp4Url! : _lesson.mp3Url!;
    setState(() {
      if (type == DownloadType.mp4) _mp4DownloadProgress = 0;
      else _mp3DownloadProgress = 0;
    });
    try {
      await DownloadService.download(
        url,
        _lesson.name,
        type,
        onProgress: (p) {
          if (mounted) setState(() {
            if (type == DownloadType.mp4) _mp4DownloadProgress = p;
            else _mp3DownloadProgress = p;
          });
        },
      );
      if (mounted) setState(() {
        if (type == DownloadType.mp4) { _mp4DownloadProgress = null; _mp4Downloaded = true; }
        else { _mp3DownloadProgress = null; _mp3Downloaded = true; }
      });
    } catch (e) {
      developer.log('DOWNLOAD_ERROR: $e');
      if (mounted) setState(() {
        if (type == DownloadType.mp4) _mp4DownloadProgress = null;
        else _mp3DownloadProgress = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Future<void> _stopAndClearWebView() async {
    if (_vimeoWebCtrl == null) return;
    await _vimeoWebCtrl!.evaluateJavascript(source: '''
      (function() {
        var v = document.querySelector('video');
        if (v) { v.pause(); v.src = ''; }
        var f = document.querySelector('iframe');
        if (f) { f.src = ''; }
      })();
    ''').catchError((_) {});
    _vimeoWebCtrl = null;
  }

  Future<void> _initializePlayers() async {
    if (!mounted) return;

    // Always stop any lingering WebView before re-initialising
    await _stopAndClearWebView();

    setState(() {
      _isLoadingMedia = true;
      _mediaError = null;
    });

    final l = widget.lesson;
    debugPrint('PLAYER ▶ "${l.name}" | mp4=${l.mp4Url ?? '-'} | vimeo=${l.vimeoUrl ?? '-'} | mp3=${l.mp3Url ?? '-'} | source=${l.sourceId}');

    try {
      _lesson = await _mediaResolver.resolve(widget.lesson);

      final videoUrl = await _mediaResolver.resolveVideoUrl(_lesson);

      if (videoUrl != null && videoUrl.isNotEmpty) {
        // HEAD check — skip ExoPlayer entirely if URL is not reachable
        int? statusCode;
        try {
          final req = await HttpClient().headUrl(Uri.parse(videoUrl));
          req.followRedirects = true;
          final res = await req.close();
          statusCode = res.statusCode;
          await res.drain();
        } catch (_) {}

        if (statusCode != null && statusCode >= 400) {
          debugPrint('PLAYER ❌ [$videoUrl] → HTTP $statusCode — skipping');
          _lesson = _lesson.copyWith(mp4Url: null);
        } else {
          debugPrint('PLAYER 🔄 [$videoUrl] → trying mp4 (HTTP ${statusCode ?? '?'})');
        try {
          _videoController = VideoPlayerController.networkUrl(
            Uri.parse(videoUrl),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          await _videoController!.initialize();
          debugPrint('PLAYER ✅ [$videoUrl] → mp4 OK');
          // mp4 succeeded — kill WebView if one was alive
          await _stopAndClearWebView();
          if (widget.resumePosition != null) {
            await _videoController!.seekTo(widget.resumePosition!);
          }
          if (mounted) setState(() => _isVideoInitialized = true);
          _videoController!.addListener(_videoListener);
        } catch (e) {
          debugPrint('PLAYER ❌ [$videoUrl] → mp4 FAIL: $e — falling back to WebView');
          _videoController?.dispose();
          _videoController = null;
          _lesson = _lesson.copyWith(vimeoUrl: videoUrl, mp4Url: null);
        }
        } // end statusCode check
      } else {
        debugPrint('PLAYER ⚠️ no video URL | hasVimeo=${_lesson.hasVimeo}');
      }

      if (!_isVideoInitialized && _lesson.hasVimeo) {
        final vimeoMatch = RegExp(r'vimeo\.com/(\d+)').firstMatch(_lesson.vimeoUrl ?? '');
        final vimeoId = vimeoMatch?.group(1);
        if (vimeoId != null) {
          debugPrint('PLAYER ✅ [${_lesson.vimeoUrl}] → Vimeo WebView (id=$vimeoId)');
          if (mounted) setState(() => _isLoadingMedia = false);
          return;
        }
        debugPrint('PLAYER ❌ [${_lesson.vimeoUrl}] → FAIL: cannot extract Vimeo ID');
      }

      if (_lesson.hasAudio) {
        debugPrint('PLAYER 🔄 [${_lesson.mp3Url}] → trying audio');
        try {
          await _initAudioPlayer();
        } catch (e) {
          debugPrint('PLAYER ❌ [${_lesson.mp3Url}] → audio FAIL: $e');
        }
      }

      if (!_isVideoInitialized && !_isAudioInitialized) {
        debugPrint('PLAYER ❌ no playable media | mp4=${_lesson.mp4Url} vimeo=${_lesson.vimeoUrl} mp3=${_lesson.mp3Url}');
        if (mounted) {
          setState(() {
            _mediaError = 'No playable media found for this lesson';
            _isLoadingMedia = false;
          });
        }
        return;
      }

      debugPrint('PLAYER ✅ ready | video=$_isVideoInitialized audio=$_isAudioInitialized');

      if (mounted) {
        setState(() {
          _isLoadingMedia = false;
          _showVideo = _isVideoInitialized;
        });
      }

      _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
    } catch (e, st) {
      debugPrint('PLAYER 💥 CRASH: $e');
      developer.log('PLAYER CRASH', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _mediaError = e.toString();
          _isLoadingMedia = false;
        });
      }
    }
  }

  Future<void> _initAudioPlayer() async {
    final mp3 = _lesson.mp3Url;
    if (mp3 == null || mp3.isEmpty) return;

    await _audioSub?.cancel();
    _audioSub = null;
    _audioPlayer = await AudioPlayerService.instance.acquire();
    try {
      await _audioPlayer!.setAudioSource(
        AudioSource.uri(
          Uri.parse(mp3),
          tag: MediaItem(id: mp3, title: _lesson.name, artist: 'בני דוד'),
        ),
      );
    } catch (e) {
      debugPrint('PLAYER ❌ [$mp3] → audio setSource FAIL: $e — retrying');
      try { await _audioPlayer!.stop(); } catch (_) {}
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setAudioSource(
        AudioSource.uri(
          Uri.parse(mp3),
          tag: MediaItem(id: mp3, title: _lesson.name, artist: 'בני דוד'),
        ),
      );
    }
    await _audioPlayer!.setSpeed(_playbackSpeed);
    if (widget.resumePosition != null) {
      await _audioPlayer!.seek(widget.resumePosition!);
    }
    if (mounted) setState(() => _isAudioInitialized = true);
    _audioSub = _audioPlayer!.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
    debugPrint('PLAYER ✅ [$mp3] → audio OK');
  }

  Future<void> _changePlaybackSpeed(double speed) async {
    if (_audioPlayer != null) {
      await _audioPlayer!.setSpeed(speed);
    }
    if (_videoController != null) {
      await _videoController!.setPlaybackSpeed(speed);
    }
    setState(() {
      _playbackSpeed = speed;
    });
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _videoListener() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveProgress() async {
    Duration position = Duration.zero;
    Duration total = Duration.zero;
    if (_videoController != null && _isVideoInitialized) {
      position = _videoController!.value.position;
      total = _videoController!.value.duration;
    } else if (_audioPlayer != null && _isAudioInitialized) {
      position = _audioPlayer!.position;
      total = _audioPlayer!.duration ?? Duration.zero;
    } else if (_vimeoWebCtrl != null) {
      try {
        final t = await _vimeoWebCtrl!.evaluateJavascript(
          source: 'document.querySelector("video")?.currentTime ?? 0',
        );
        final d = await _vimeoWebCtrl!.evaluateJavascript(
          source: 'document.querySelector("video")?.duration ?? 0',
        );
        final tSec = (t as num?)?.toInt() ?? 0;
        final dSec = (d as num?)?.toInt() ?? 0;
        if (dSec > 0) {
          position = Duration(seconds: tSec);
          total = Duration(seconds: dSec);
        }
      } catch (_) {}
    }
    if (total > Duration.zero) {
      await _historyService.saveLesson(_lesson, position, total);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveProgress();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _audioSub?.cancel();
    if (_audioPlayer != null) {
      AudioPlayerService.instance.stop();
      _audioPlayer = null;
    }
    // Stop Vimeo / HTML5 WebView playback before the view is destroyed
    _vimeoWebCtrl?.evaluateJavascript(source: '''
      (function() {
        var v = document.querySelector('video');
        if (v) { v.pause(); v.src = ''; }
        var f = document.querySelector('iframe');
        if (f) { f.src = ''; }
      })();
    ''').catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return _buildFullScreenVideo();
    }
    
    final l10n = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isHebrew = languageProvider.locale.languageCode == 'he';
    return Scaffold(
      appBar: AppBar(
        title: Text(_lesson.name),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: isHebrew ? null : const BackButton(),
        actions: isHebrew ? [const BackButton()] : null,
      ),
      body: Column(
        children: [
          if (!_isLoadingMedia && _mediaError == null) ...[
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isVideoInitialized)
                    ChoiceChip(
                      label: Text(l10n.video),
                      selected: _showVideo,
                      onSelected: (_) => setState(() => _showVideo = true),
                    ),
                  if (_isAudioInitialized)
                    ChoiceChip(
                      label: Text(l10n.audio),
                      selected: !_showVideo,
                      onSelected: (_) => setState(() => _showVideo = false),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_lesson.hasMp4)
                    _DownloadButton(
                      label: isHebrew ? 'הורד MP4' : 'Download MP4',
                      icon: Icons.video_file_outlined,
                      downloaded: _mp4Downloaded,
                      progress: _mp4DownloadProgress,
                      onTap: _mp4DownloadProgress == null && !_mp4Downloaded
                          ? () => _download(DownloadType.mp4)
                          : null,
                    ),
                  if (_lesson.hasAudio)
                    _DownloadButton(
                      label: isHebrew ? 'הורד MP3' : 'Download MP3',
                      icon: Icons.audio_file_outlined,
                      downloaded: _mp3Downloaded,
                      progress: _mp3DownloadProgress,
                      onTap: _mp3DownloadProgress == null && !_mp3Downloaded
                          ? () => _download(DownloadType.mp3)
                          : null,
                    ),
                  _DownloadButton(
                    label: isHebrew ? 'מדיה שמורה' : 'Saved Media',
                    icon: Icons.folder_open,
                    downloaded: false,
                    progress: null,
                    onTap: () async {
                      if (_audioPlayer != null) {
                        await _audioSub?.cancel();
                        _audioSub = null;
                        await AudioPlayerService.instance.stop();
                        _audioPlayer = null;
                        if (mounted) setState(() => _isAudioInitialized = false);
                      }
                      // if (!context.mounted) return;
                      // await Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //      // builder: (_) => const OfflineLibraryScreen()),
                      // );
                      if (mounted && _lesson.hasAudio) {
                        await _initAudioPlayer();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: _isLoadingMedia
                ? const Center(child: CircularProgressIndicator())
                : _mediaError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_mediaError!,
                              textAlign: TextAlign.center),
                        ),
                      )
                    : _lesson.hasVimeo && !_isVideoInitialized
                        ? _buildVimeoFallback()
                        : _showVideo && _isVideoInitialized
                            ? _buildVideoPlayer()
                            : _buildAudioPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenVideo() {
    if (!_isVideoInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seek slider
                  Builder(builder: (context) {
                    final position = _videoController!.value.position;
                    final duration = _videoController!.value.duration;
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white38,
                            thumbColor: Colors.white,
                            overlayColor: Colors.white24,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            value: progress.clamp(0.0, 1.0),
                            onChanged: (v) {
                              final target = Duration(
                                  milliseconds: (v *
                                          duration.inMilliseconds)
                                      .round());
                              _videoController!.seekTo(target);
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white70)),
                            Text(_formatDuration(duration),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                  // Speed + controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fullscreen_exit,
                            color: Colors.white, size: 32),
                        onPressed: _toggleFullScreen,
                      ),
                      IconButton(
                        icon: Icon(
                          _videoController!.value.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          color: Colors.white,
                          size: 52,
                        ),
                        onPressed: () => setState(() {
                          _videoController!.value.isPlaying
                              ? _videoController!.pause()
                              : _videoController!.play();
                        }),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<double>(
                            value: _playbackSpeed,
                            dropdownColor: Colors.black87,
                            isDense: true,
                            style:
                                const TextStyle(color: Colors.white),
                            items: _availableSpeeds
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('${s}x')))
                                .toList(),
                            onChanged: (s) {
                              if (s != null) _changePlaybackSpeed(s);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Widget _buildVimeoFallback() {
    final rawUrl = _lesson.vimeoUrl!;

    // Direct mp4 URL (codec fallback) — embed via HTML5 <video>
    if (rawUrl.contains('.mp4') || rawUrl.startsWith('https://secure.media-line')) {
      debugPrint('PLAYER ✅ [$rawUrl] → HTML5 video WebView');
      final html = '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
* { margin:0; padding:0; box-sizing:border-box; }
html, body { width:100%; height:100%; background:#000; }
video { width:100%; height:100%; object-fit:contain; }
</style>
</head>
<body>
<video controls autoplay playsinline src="$rawUrl"></video>
</body>
</html>''';
      return InAppWebView(
        initialData: InAppWebViewInitialData(data: html, mimeType: 'text/html'),
        initialSettings: InAppWebViewSettings(
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          javaScriptEnabled: true,
          useHybridComposition: true,
        ),
        onWebViewCreated: (c) => _vimeoWebCtrl = c,
        onReceivedError: (c, req, err) =>
            debugPrint('PLAYER ❌ [${req.url}] → WebView error: ${err.description}'),
      );
    }

    // Vimeo embed
    final match = RegExp(r'vimeo\.com/(\d+)').firstMatch(rawUrl);
    final videoId = match?.group(1) ?? '';
    final embedUrl = 'https://player.vimeo.com/video/$videoId?autoplay=1&api=1';
    debugPrint('PLAYER ✅ [$rawUrl] → Vimeo embed (id=$videoId)');

    if (videoId.isEmpty) {
      debugPrint('PLAYER ❌ [$rawUrl] → FAIL: no Vimeo ID');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_outline, size: 72, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('הסרטון זמין בוימאו', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('צפה בוימאו'),
              onPressed: () => launchUrl(Uri.parse(rawUrl), mode: LaunchMode.externalApplication),
            ),
          ],
        ),
      );
    }

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
<iframe id="player" src="$embedUrl" allow="autoplay; fullscreen; picture-in-picture" allowfullscreen></iframe>
</body>
</html>''';

    return InAppWebView(
      initialData: InAppWebViewInitialData(data: html, mimeType: 'text/html'),
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        javaScriptEnabled: true,
        useHybridComposition: true,
      ),
      onWebViewCreated: (c) => _vimeoWebCtrl = c,
      onReceivedError: (c, req, err) =>
          debugPrint('PLAYER ❌ [${req.url}] → WebView error: ${err.description}'),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isVideoInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),

        // Seek slider + time labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) {
                      final target = Duration(
                          milliseconds:
                              (v * duration.inMilliseconds).round());
                      _videoController!.seekTo(target);
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    Text(_formatDuration(duration),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Speed + fullscreen + play
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Speed dropdown
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<double>(
                    value: _playbackSpeed,
                    isDense: true,
                    items: _availableSpeeds
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text('${s}x')))
                        .toList(),
                    onChanged: (s) {
                      if (s != null) _changePlaybackSpeed(s);
                    },
                  ),
                ),
              ),
              // Play / pause
              IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  size: 52,
                ),
                onPressed: () => setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                }),
              ),
              // Fullscreen
              IconButton(
                icon: const Icon(Icons.fullscreen, size: 32),
                onPressed: _toggleFullScreen,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPlayer() {
    final l10n = AppLocalizations.of(context);
    if (!_isAudioInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.audiotrack,
          size: 100,
          color: Colors.green,
        ),
        const SizedBox(height: 24),
        
        // Speed selection
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.translate('playback_speed'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<double>(
                    value: _playbackSpeed,
                    items: _availableSpeeds.map((speed) {
                      return DropdownMenuItem<double>(
                        value: speed,
                        child: Text('${speed}x'),
                      );
                    }).toList(),
                    onChanged: (speed) {
                      if (speed != null) {
                        _changePlaybackSpeed(speed);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Audio controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10, size: 40),
              onPressed: () {
                final position = _audioPlayer!.position;
                _audioPlayer!.seek(position - const Duration(seconds: 10));
              },
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle : Icons.play_circle,
                size: 64,
              ),
              onPressed: () {
                if (_isPlaying) {
                  _audioPlayer!.pause();
                } else {
                  _audioPlayer!.play();
                }
              },
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.forward_10, size: 40),
              onPressed: () {
                final position = _audioPlayer!.position;
                _audioPlayer!.seek(position + const Duration(seconds: 10));
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _DownloadButton
// ---------------------------------------------------------------------------

class _DownloadButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool downloaded;
  final double? progress;
  final VoidCallback? onTap;

  const _DownloadButton({
    required this.label,
    required this.icon,
    required this.downloaded,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = downloaded
        ? Colors.green
        : progress != null
            ? Colors.orange
            : const Color(0xFF1976D2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (progress != null)
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      color: Colors.orange,
                    ),
                  ),
                Icon(
                  downloaded ? Icons.check_circle : icon,
                  color: color,
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              progress != null
                  ? '${((progress ?? 0) * 100).round()}%'
                  : label,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
