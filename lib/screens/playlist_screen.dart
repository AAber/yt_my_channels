import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/playlist_service.dart';
import '../services/media_button_service.dart';
import '../widgets/add_to_playlist_sheet.dart';
import 'youtube_player_screen.dart';
import '../services/youtube_service.dart';

// ── Playlist list screen ──────────────────────────────────────────────────────

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: PlaylistService.instance,
      child: const _PlaylistScreenBody(),
    );
  }
}

class _PlaylistScreenBody extends StatelessWidget {
  const _PlaylistScreenBody();

  void _createPlaylist(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await PlaylistService.instance.createPlaylist(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistService>().playlists;

    return Scaffold(
      appBar: AppBar(title: const Text('Playlists'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createPlaylist(context),
        child: const Icon(Icons.add),
      ),
      body: playlists.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.queue_music, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No playlists yet',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Tap + to create one',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: playlists.length,
              itemBuilder: (context, i) {
                final pl = playlists[i];
                return ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(pl.name),
                  subtitle: Text('${pl.videos.length} videos'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pl.videos.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline),
                          tooltip: 'Play',
                          onPressed: () => _launchPlayer(context, pl, shuffle: false),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, pl),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _PlaylistDetailScreen(playlist: pl)),
                  ),
                );
              },
            ),
    );
  }

  void _launchPlayer(BuildContext context, Playlist pl,
      {required bool shuffle}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistPlayerScreen(
          playlist: pl,
          shuffle: shuffle,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Playlist pl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text('Delete "${pl.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await PlaylistService.instance.deletePlaylist(pl.id);
    }
  }
}

// ── Playlist detail screen ────────────────────────────────────────────────────

class _PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  const _PlaylistDetailScreen({required this.playlist});

  @override
  State<_PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<_PlaylistDetailScreen> {
  bool _shuffle = false;

  void _play(List<PlaylistVideo> videos, int startIndex) {
    final ordered = _shuffle
        ? (List<PlaylistVideo>.from(videos)..shuffle(Random()))
        : videos;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistPlayerScreen(
          playlist: Playlist(
            id: widget.playlist.id,
            name: widget.playlist.name,
            videos: ordered,
          ),
          startIndex: _shuffle ? 0 : startIndex,
          shuffle: false, // already shuffled above
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: PlaylistService.instance,
      child: Consumer<PlaylistService>(
        builder: (context, service, _) {
          final pl = service.playlists.firstWhere(
            (p) => p.id == widget.playlist.id,
            orElse: () => widget.playlist,
          );

          return Scaffold(
            appBar: AppBar(
              title: Text(pl.name),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: _shuffle ? 'Shuffle on' : 'Shuffle off',
                  icon: Icon(
                    Icons.shuffle,
                    color: _shuffle
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: () => setState(() => _shuffle = !_shuffle),
                ),
              ],
            ),
            body: pl.videos.isEmpty
                ? const Center(
                    child: Text('No videos in this playlist',
                        style: TextStyle(color: Colors.grey)),
                  )
                : Column(
                    children: [
                      // ── Play header ──────────────────────────────────
                      _PlayHeader(
                        count: pl.videos.length,
                        shuffle: _shuffle,
                        onPlay: () => _play(pl.videos, 0),
                        onToggleShuffle: () =>
                            setState(() => _shuffle = !_shuffle),
                      ),
                      // ── Video list ───────────────────────────────────
                      Expanded(
                        child: ListView.builder(
                          itemCount: pl.videos.length,
                          itemBuilder: (context, i) {
                            final v = pl.videos[i];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  v.thumbnailUrl,
                                  width: 64,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.play_circle_outline,
                                      size: 36),
                                ),
                              ),
                              title: Text(v.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(v.channelTitle,
                                  style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red),
                                onPressed: () => PlaylistService.instance
                                    .removeVideo(pl.id, v.id),
                              ),
                              onTap: () => _play(pl.videos, i),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

// ── Play header bar ───────────────────────────────────────────────────────────

class _PlayHeader extends StatelessWidget {
  final int count;
  final bool shuffle;
  final VoidCallback onPlay;
  final VoidCallback onToggleShuffle;

  const _PlayHeader({
    required this.count,
    required this.shuffle,
    required this.onPlay,
    required this.onToggleShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Text('$count videos',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Spacer(),
          // Shuffle toggle
          IconButton(
            icon: Icon(Icons.shuffle,
                color: shuffle ? primary : Colors.grey),
            tooltip: shuffle ? 'Shuffle on' : 'Shuffle off',
            onPressed: onToggleShuffle,
          ),
          // Play button
          FilledButton.icon(
            onPressed: onPlay,
            icon: Icon(shuffle ? Icons.shuffle : Icons.play_arrow),
            label: Text(shuffle ? 'Shuffle' : 'Play All'),
          ),
        ],
      ),
    );
  }
}

// ── Playlist player screen ────────────────────────────────────────────────────

class PlaylistPlayerScreen extends StatefulWidget {
  final Playlist playlist;
  final int startIndex;
  final bool shuffle;

  const PlaylistPlayerScreen({
    super.key,
    required this.playlist,
    this.startIndex = 0,
    this.shuffle = false,
  });

  @override
  State<PlaylistPlayerScreen> createState() => _PlaylistPlayerScreenState();
}

class _PlaylistPlayerScreenState extends State<PlaylistPlayerScreen> {
  late List<PlaylistVideo> _queue;
  late int _index;
  bool _shuffle = false;

  YoutubePlayerController? _controller;
  bool _playerReady = false;
  bool _endedHandled = false;

  @override
  void initState() {
    super.initState();
    _shuffle = widget.shuffle;
    _queue = List<PlaylistVideo>.from(widget.playlist.videos);
    if (_shuffle) _queue.shuffle(Random());
    _index = widget.startIndex.clamp(0, _queue.length - 1);
    if (_queue.isNotEmpty) _loadVideo(_queue[_index].id);
    MediaButtonService.instance.register(_onMediaButton);
  }

  @override
  void dispose() {
    MediaButtonService.instance.unregister();
    _controller?.removeListener(_onPlayerEvent);
    _controller?.dispose();
    super.dispose();
  }

  void _loadVideo(String videoId) {
    _endedHandled = false;
    _playerReady = false;
    if (_controller == null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          hideControls: true,
          enableCaption: false,
          forceHD: false,
          showLiveFullscreenButton: false,
        ),
      )..addListener(_onPlayerEvent);
    } else {
      _controller!.load(videoId);
    }
  }

  void _onPlayerEvent() {
    if (!mounted || _controller == null) return;
    final v = _controller!.value;

    if (!_playerReady &&
        v.playerState != PlayerState.unknown &&
        v.playerState != PlayerState.unStarted) {
      _playerReady = true;
    }

    if (v.hasError && !_endedHandled) {
      _endedHandled = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) { if (mounted) _playNext(); });
    }

    if (v.playerState == PlayerState.ended && !_endedHandled) {
      _endedHandled = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) { if (mounted) _playNext(); });
    }

    setState(() {});
  }

  void _playNext() {
    if (_queue.isEmpty) return;
    final next = (_index + 1) % _queue.length;
    setState(() => _index = next);
    _loadVideo(_queue[next].id);
  }

  void _playPrev() {
    if (_queue.isEmpty) return;
    final prev = (_index - 1 + _queue.length) % _queue.length;
    setState(() => _index = prev);
    _loadVideo(_queue[prev].id);
  }

  void _playAt(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _loadVideo(_queue[i].id);
  }

  void _togglePlayPause() {
    final v = _controller?.value;
    if (v == null) return;
    v.isPlaying ? _controller!.pause() : _controller!.play();
  }

  void _toggleShuffle() {
    setState(() {
      _shuffle = !_shuffle;
      final current = _queue[_index];
      if (_shuffle) {
        _queue.shuffle(Random());
        // keep current video at front
        _queue.remove(current);
        _queue.insert(0, current);
      } else {
        // restore original order
        _queue = List<PlaylistVideo>.from(widget.playlist.videos);
      }
      _index = _queue.indexWhere((v) => v.id == current.id);
      if (_index == -1) _index = 0;
    });
  }

  void _onMediaButton(String action) {
    switch (action) {
      case 'play_pause': _togglePlayPause(); break;
      case 'next':       _playNext();        break;
      case 'previous':   _playPrev();        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.playlist.name)),
        body: const Center(child: Text('No videos in playlist')),
      );
    }

    final current = _queue[_index];
    final player = YoutubePlayer(
      controller: _controller!,
      showVideoProgressIndicator: false,
      onReady: () { if (mounted) setState(() => _playerReady = true); },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.shuffle,
              color: _shuffle ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: _shuffle ? 'Shuffle on' : 'Shuffle off',
            onPressed: _toggleShuffle,
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -300) _playNext();
          if ((d.primaryVelocity ?? 0) > 300) _playPrev();
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Player ────────────────────────────────────────────────
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

              // ── Controls ──────────────────────────────────────────────
              _buildControls(),

              // ── Now playing info ──────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(current.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(current.channelTitle,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                    Text('${_index + 1} / ${_queue.length}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Queue list ────────────────────────────────────────────
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _queue.length,
                  itemBuilder: (context, i) {
                    final item = _queue[i];
                    final isCurrent = i == _index;
                    return ListTile(
                      dense: true,
                      selected: isCurrent,
                      selectedTileColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      leading: isCurrent
                          ? Icon(Icons.play_arrow,
                              color: Theme.of(context).primaryColor)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12)),
                      title: Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      subtitle: Text(item.channelTitle,
                          style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.playlist_add, size: 20),
                        onPressed: () => showAddToPlaylistSheet(
                          context,
                          item,
                        ),
                      ),
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
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
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

// Helper: open a single video from a PlaylistVideo (used from detail screen)
YouTubeVideo _toYTVideo(PlaylistVideo v) => YouTubeVideo(
      id: v.id,
      title: v.title,
      description: '',
      thumbnailUrl: v.thumbnailUrl,
      publishedAt: DateTime.now(),
    );
