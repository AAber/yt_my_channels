import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:provider/provider.dart';
import '../l10n/language_provider.dart';
import '../services/saved_channels_service.dart';
import '../services/deeplink_service.dart';
import '../services/youtube_service.dart';
import 'dart:developer' as developer;

class ShufflePlayScreen extends StatefulWidget {
  const ShufflePlayScreen({super.key});

  @override
  State<ShufflePlayScreen> createState() => _ShufflePlayScreenState();
}

class _ShufflePlayScreenState extends State<ShufflePlayScreen> {
  final _ytService = YouTubeService();

  List<_QueueItem> _queue = [];
  int _index = 0;
  bool _loading = true;
  String? _error;

  // A single controller lives for the whole session. We swap videos with
  // controller.load(id) instead of disposing/recreating the controller —
  // recreating it broke the underlying webview binding and left buttons
  // permanently disabled after the first track.
  YoutubePlayerController? _controller;
  bool _playerReady = false;

  // Prevents a single "ended" state from being handled more than once
  // (the controller can emit the ended state repeatedly in a row).
  bool _endedHandledForCurrentVideo = false;

  @override
  void initState() {
    super.initState();
    _buildQueue();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerEvent);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _buildQueue() async {
    setState(() { _loading = true; _error = null; });
    final channels = SavedChannelsService.instance.channels;
    if (channels.isEmpty) {
      setState(() { _loading = false; _error = 'No channels saved.'; });
      return;
    }

    final items = <_QueueItem>[];
    for (final ch in channels) {
      try {
        final videos = await _ytService.getChannelVideos(channelId: ch.id, maxResults: 50);
        for (final v in videos) {
          items.add(_QueueItem(video: v, channelTitle: ch.title));
        }
      } catch (e) {
        developer.log('ShufflePlay: failed to load ${ch.title}: $e');
      }
    }

    if (items.isEmpty) {
      setState(() { _loading = false; _error = 'Could not load any videos.'; });
      return;
    }

    items.shuffle(Random());
    setState(() {
      _queue = items;
      _index = 0;
      _loading = false;
    });
    _loadVideo(_queue[0].video.id);
  }

  // Loads a video into the persistent controller, creating it only once.
  void _loadVideo(String videoId) {
    _endedHandledForCurrentVideo = false;

    if (_controller == null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          hideControls: true,
          enableCaption: false,
          showLiveFullscreenButton: false,
        ),
      )..addListener(_onPlayerEvent);
    } else {
      _controller!.load(videoId);
    }
  }

  // Fires continuously as the controller's position/play-state changes.
  // We rebuild so the slider and play/pause icon stay live, mark the
  // player as ready once it's actually producing state, and detect
  // end-of-video to auto-advance exactly once per track.
  void _onPlayerEvent() {
    if (!mounted || _controller == null) return;
    final v = _controller!.value;

    if (!_playerReady &&
        v.playerState != PlayerState.unknown &&
        v.playerState != PlayerState.unStarted) {
      _playerReady = true;
    }

    // Error 150 = playback disabled by video owner; skip silently
    if (v.hasError && !_endedHandledForCurrentVideo) {
      _endedHandledForCurrentVideo = true;
      developer.log('ShufflePlay: skipping video error ${v.errorCode} on ${_queue[_index].video.id}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playNext();
      });
    }

    if (v.playerState == PlayerState.ended && !_endedHandledForCurrentVideo) {
      _endedHandledForCurrentVideo = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playNext();
      });
    }

    setState(() {});
  }

  // Share ↑ — the app link with OG preview
  void _shareNowPlaying() {
    if (_queue.isEmpty) return;
    final current = _queue[_index];
    Share.share(
      '🎵 "${current.video.title}"\n'
      '${current.channelTitle}\n\n'
      'https://myyt.isaac770.live/',
      subject: current.video.title,
    );
  }

  // Share ≡▶ — the full channel playlist as a deeplink
  void _sharePlaylist() {
    final channels = SavedChannelsService.instance.channels;
    if (channels.isEmpty) return;
    final url = DeeplinkService.buildShareUrl(channels.toList());
    final names = channels.map((c) => c.title).join(' · ');
    Share.share(
      '🎵 My YT Channels playlist\n$names\n\n'
      'Tap to install the app and load my channels automatically 👇\n$url',
      subject: 'My YT Channels playlist',
    );
  }

  void _playNext() {
    if (_queue.isEmpty) return;
    final next = (_index + 1) % _queue.length;
    setState(() => _index = next);
    _loadVideo(_queue[next].video.id);
  }

  void _playPrev() {
    if (_queue.isEmpty) return;
    final prev = (_index - 1 + _queue.length) % _queue.length;
    setState(() => _index = prev);
    _loadVideo(_queue[prev].video.id);
  }

  void _playAt(int i) {
    if (_queue.isEmpty || i == _index) return;
    setState(() => _index = i);
    _loadVideo(_queue[i].video.id);
  }

  void _togglePlayPause() {
    final v = _controller?.value;
    if (v == null) return;
    if (v.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHebrew = Provider.of<LanguageProvider>(context, listen: false)
            .locale.languageCode == 'he';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shuffle Play')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading videos from all channels…'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shuffle Play')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _buildQueue, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final current = _queue[_index];

    // NOTE: intentionally NOT wrapped in YoutubePlayerBuilder.
    //
    // YoutubePlayerBuilder auto-switches into a full-screen overlay
    // whenever it detects a landscape orientation, and expects the user
    // to either rotate back to portrait or use the system back
    // button/gesture to exit it. Car head units are permanently
    // landscape and typically have no back gesture, so that overlay
    // triggers immediately on load with no way out — appbar, swipe
    // handler, and all custom controls end up buried underneath it.
    //
    // This screen already implements 100% of its own playback UI
    // (play/pause, skip, slider, queue), so YouTube's own fullscreen
    // mode isn't needed — keeping the player as a plain widget means it
    // never leaves this Scaffold, and the appbar/back button/swipe
    // gestures are always reachable, on every device.
    final player = YoutubePlayer(
      controller: _controller!,
      showVideoProgressIndicator: false,
      onReady: () {
        if (mounted) setState(() => _playerReady = true);
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shuffle Play'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: isHebrew ? null : const BackButton(),
        actions: [
          if (isHebrew) const BackButton(),
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Share now playing',
            onPressed: _queue.isEmpty ? null : _shareNowPlaying,
          ),
          IconButton(
            icon: const Icon(Icons.playlist_play),
            tooltip: 'Share full playlist',
            onPressed: _queue.isEmpty ? null : _sharePlaylist,
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Reshuffle',
            onPressed: _buildQueue,
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -300) _playNext();
          if (details.primaryVelocity! > 300) _playPrev();
        },
        child: SingleChildScrollView(
          child: Column(
          children: [
            // ── Player ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    player,
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _togglePlayPause,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Controls ─────────────────────────────────────────────────
            _buildControls(),

            // ── Now playing info ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(current.video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(current.channelTitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  Text('${_index + 1} / ${_queue.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Queue list ───────────────────────────────────────────────
            SizedBox(
              height: 300, // Adjust this height as needed
              child: ListView.builder(
                itemCount: _queue.length,
                itemBuilder: (context, i) {
                  final item = _queue[i];
                  final isCurrent = i == _index;
                  return ListTile(
                    dense: true,
                    selected: isCurrent,
                    selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                    leading: isCurrent
                        ? Icon(Icons.play_arrow,
                            color: Theme.of(context).primaryColor)
                        : Text('${i + 1}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    title: Text(item.video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    subtitle: Text(item.channelTitle,
                        style: const TextStyle(fontSize: 11)),
                    onTap: () => _playAt(i),
                  );
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final v = _controller?.value;
    final position = v?.position ?? Duration.zero;
    final duration = v?.metaData.duration ?? Duration.zero;
    final isPlaying = v?.isPlaying ?? false;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Slider(
              value: progress.toDouble(),
              onChanged: _playerReady && duration.inMilliseconds > 0
                  ? (val) => _controller!.seekTo(duration * val)
                  : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: _playerReady ? _playPrev : null,
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 44,
                ),
                onPressed: _playerReady ? _togglePlayPause : null,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: _playerReady ? _playNext : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QueueItem {
  final YouTubeVideo video;
  final String channelTitle;
  const _QueueItem({required this.video, required this.channelTitle});
}
