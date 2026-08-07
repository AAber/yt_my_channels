import 'dart:async';
import 'dart:developer' as developer;
import 'package:video_player/video_player.dart';

const _tag = 'THUMB_CACHE';

/// Initialises [VideoPlayerController]s one at a time (serial queue) so
/// Android's MediaCodec hardware decoder limit is never exceeded.
/// Each controller is seeked to 0 and paused — first frame only.
class VideoThumbnailCache {
  VideoThumbnailCache._();
  static final VideoThumbnailCache instance = VideoThumbnailCache._();

  final Map<String, VideoPlayerController> _ready = {};
  final Map<String, Completer<VideoPlayerController?>> _completers = {};
  final List<String> _queue = [];
  bool _processing = false;

  /// Returns a ready controller for [url], queuing initialisation if needed.
  Future<VideoPlayerController?> get(String url) {
    if (_ready.containsKey(url)) return Future.value(_ready[url]);
    if (_completers.containsKey(url)) return _completers[url]!.future;

    final completer = Completer<VideoPlayerController?>();
    _completers[url] = completer;
    _queue.add(url);
    _pump();
    return completer.future;
  }

  void _pump() {
    if (_processing || _queue.isEmpty) return;
    _processing = true;
    final url = _queue.removeAt(0);
    _init(url).then((ctrl) {
      _processing = false;
      _completers.remove(url)?.complete(ctrl);
      _pump();
    });
  }

  Future<VideoPlayerController?> _init(String url) async {
    developer.log('$_tag: init $url', name: _tag);
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      await ctrl.setVolume(0);
      await ctrl.seekTo(Duration.zero);
      // Play briefly then pause so the first frame is actually rendered
      await ctrl.play();
      await Future.delayed(const Duration(milliseconds: 200));
      await ctrl.pause();
      await ctrl.seekTo(Duration.zero);
      _ready[url] = ctrl;
      developer.log('$_tag: ready $url', name: _tag);
      return ctrl;
    } catch (e) {
      developer.log('$_tag: FAILED $url — $e', name: _tag);
      return null;
    }
  }

  void evictAll() {
    for (final ctrl in _ready.values) {
      ctrl.dispose();
    }
    _ready.clear();
    _queue.clear();
    // complete any pending with null
    for (final c in _completers.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _completers.clear();
    _processing = false;
    developer.log('$_tag: evicted all', name: _tag);
  }
}
