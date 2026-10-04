import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../l10n/language_provider.dart';
import '../services/youtube_service.dart';
import '../services/watch_history_service.dart';

class YouTubePlayerScreen extends StatefulWidget {
  final YouTubeVideo video;
  final String channelTitle;
  final Duration? resumePosition;

  const YouTubePlayerScreen({
    super.key,
    required this.video,
    this.channelTitle = '',
    this.resumePosition,
  });

  @override
  State<YouTubePlayerScreen> createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  bool _hasError = false;
  bool _lowQualityApplied = false;
  String? _errorMessage;
  Timer? _saveTimer;
  final WatchHistoryService _historyService = WatchHistoryService();

  // Small preview size. YouTube picks the stream resolution based on the
  // size of the player, so a tiny player => 144p/240p video => far less data.
  static const double _previewWidth = 192; // 16:9 -> 108 high

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _historyService.init();
  }

  void _initializePlayer() {
    try {
      developer.log(
          'YT_PLAYER: Initializing player for video ID: ${widget.video.id}');

      _controller = YoutubePlayerController(
        initialVideoId: widget.video.id,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          hideControls: true,
          disableDragSeek: false,
          enableCaption: false,
          forceHD: false, // never request HD
          showLiveFullscreenButton: false,
        ),
      )..addListener(_playerListener);
    } catch (e) {
      developer.log('YT_ERROR: Failed to initialize player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// Ask the embedded YouTube iframe for the lowest quality ("tiny" = 144p).
  /// This is a hint; YouTube may ignore it, but the small player size above
  /// makes adaptive streaming choose a low resolution anyway.
  void _applyLowQuality() {
    try {
      final web = _controller.value.webViewController;
      web?.evaluateJavascript(source: "player.setPlaybackQuality('tiny');");
      developer.log('YT_PLAYER: Requested lowest playback quality');
    } catch (e) {
      developer.log('YT_PLAYER: Could not set quality: $e');
    }
  }

  void _playerListener() {
    if (!_isPlayerReady || !mounted) return;

    // Re-apply once playback actually starts (quality hints set before the
    // stream is loaded are sometimes dropped).
    if (!_lowQualityApplied && _controller.value.isPlaying) {
      _lowQualityApplied = true;
      _applyLowQuality();
    }

    if (_controller.value.errorCode != 0) {
      final errorCode = _controller.value.errorCode;
      String errorMessage;
      if (errorCode == 101 || errorCode == 150) {
        errorMessage =
            'This video is restricted from playing in embedded players.';
        developer.log(
            'YT_ERROR: Video restricted from embedding. Video ID: ${widget.video.id}, Error Code: $errorCode');
      } else {
        switch (errorCode) {
          case 2:
            errorMessage = 'The request contains an invalid parameter value.';
            break;
          case 5:
            errorMessage = 'An error related to the HTML5 player has occurred.';
            break;
          case 100:
            errorMessage = 'The video requested was not found.';
            break;
          default:
            errorMessage =
                'An unknown error occurred with the player (code: $errorCode).';
        }
        developer.log(
            'YT_ERROR: Player error. Code: $errorCode, Video ID: ${widget.video.id}');
      }

      setState(() {
        _hasError = true;
        _errorMessage = errorMessage;
      });
    } else if (_hasError) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _saveProgress() async {
    if (!_isPlayerReady) return;
    final position = _controller.value.position;
    final totalSeconds = _controller.metadata.duration.inSeconds;
    if (totalSeconds > 0) {
      await _historyService.saveYouTube(
        widget.video,
        widget.channelTitle,
        position,
        Duration(seconds: totalSeconds),
      );
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_isPlayerReady) _saveProgress();
    developer.log('YT_PLAYER: Disposing player controller');
    _controller.removeListener(_playerListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final isHebrew = languageProvider.locale.languageCode == 'he';

    final player = YoutubePlayer(
      controller: _controller,
      width: _previewWidth,
      aspectRatio: 16 / 9,
      showVideoProgressIndicator: false,
      onReady: () {
        developer.log('YT_PLAYER: Player is ready');
        if (mounted) {
          setState(() => _isPlayerReady = true);
          _applyLowQuality();
          if (widget.resumePosition != null) {
            _controller.seekTo(widget.resumePosition!);
          }
          _saveTimer = Timer.periodic(
            const Duration(seconds: 10),
            (_) => _saveProgress(),
          );
        }
      },
      onEnded: (metaData) => developer.log('YT_PLAYER: Video ended.'),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: isHebrew ? null : const BackButton(),
        actions: isHebrew ? [const BackButton()] : null,
      ),
      body: ListView(
        children: [
          // Small, low-bandwidth video preview (audio plays in full)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Center(
              child: SizedBox(
                width: _previewWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _hasError
                      ? AspectRatio(
                          aspectRatio: 16 / 9, child: _buildErrorWidget())
                      : player,
                ),
              ),
            ),
          ),
          if (!_hasError)
            _ControlsBar(controller: _controller, isReady: _isPlayerReady),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: _hasError ? Colors.red.shade50 : Colors.blue.shade50,
                  child: InkWell(
                    onTap: () async {
                      final url =
                          'https://www.youtube.com/watch?v=${widget.video.id}';
                      developer
                          .log('YT_PLAYER: Opening external YouTube URL: $url');
                      try {
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                        } else {
                          developer.log('YT_PLAYER: Cannot launch URL: $url');
                        }
                      } catch (e) {
                        developer.log('YT_PLAYER: Error launching URL: $e');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            _hasError ? Icons.error : Icons.open_in_new,
                            color: _hasError ? Colors.red : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _hasError
                                  ? 'שגיאה בנגן - לחץ לצפייה ביוטיוב'
                                  : 'אם הסרטון לא נטען, לחץ כאן לצפייה ביוטיוב',
                              style: TextStyle(
                                color: _hasError
                                    ? Colors.red.shade700
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.video.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDate(widget.video.publishedAt),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                if (widget.video.description.isNotEmpty) ...[
                  const Text(
                    'תיאור:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.video.description,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return 'לפני $years ${years == 1 ? 'שנה' : 'שנים'}';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return 'לפני $months ${months == 1 ? 'חודש' : 'חודשים'}';
    } else if (difference.inDays > 0) {
      return 'לפני ${difference.inDays} ${difference.inDays == 1 ? 'יום' : 'ימים'}';
    } else if (difference.inHours > 0) {
      return 'לפני ${difference.inHours} ${difference.inHours == 1 ? 'שעה' : 'שעות'}';
    } else {
      return 'לפני ${difference.inMinutes} דקות';
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 28, color: Colors.red.shade400),
          const SizedBox(height: 4),
          Text(
            'שגיאה בטעינת הסרטון',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () {
              developer.log('YT_PLAYER: Retrying to play video');
              setState(() {
                _hasError = false;
                _errorMessage = null;
                _lowQualityApplied = false;
              });
              _controller.load(widget.video.id);
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('נסה שוב', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _ControlsBar extends StatefulWidget {
  final YoutubePlayerController controller;
  final bool isReady;

  const _ControlsBar({required this.controller, required this.isReady});

  @override
  State<_ControlsBar> createState() => _ControlsBarState();
}

class _ControlsBarState extends State<_ControlsBar> {
  double _speed = 1.0;
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.controller.value;
    final position = v.position;
    final duration = v.metaData.duration;
    final isPlaying = v.isPlaying;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Slider(
              value: progress.toDouble(),
              onChanged: widget.isReady && duration.inMilliseconds > 0
                  ? (val) => widget.controller.seekTo(duration * val)
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(_fmt(position), style: const TextStyle(fontSize: 12)),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 40,
                  ),
                  onPressed: widget.isReady
                      ? () => isPlaying
                          ? widget.controller.pause()
                          : widget.controller.play()
                      : null,
                ),
                const Spacer(),
                Text(_fmt(duration), style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                DropdownButton<double>(
                  value: _speed,
                  underline: const SizedBox(),
                  items: _speeds
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text('${s}x')))
                      .toList(),
                  onChanged: widget.isReady
                      ? (s) {
                          if (s == null) return;
                          widget.controller.setPlaybackRate(s);
                          setState(() => _speed = s);
                        }
                      : null,
                ),
                // Fullscreen button removed: fullscreen makes YouTube stream
                // high-resolution video again.
              ],
            ),
          ),
        ],
      ),
    );
  }
}
