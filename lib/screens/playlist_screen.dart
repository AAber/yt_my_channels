import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/playlist_service.dart';
import 'youtube_player_screen.dart';
import '../services/youtube_service.dart';

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
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
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
                    },
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
}

class _PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistDetailScreen({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: PlaylistService.instance,
      child: Consumer<PlaylistService>(
        builder: (context, service, _) {
          final pl = service.playlists.firstWhere(
            (p) => p.id == playlist.id,
            orElse: () => playlist,
          );

          return Scaffold(
            appBar: AppBar(
              title: Text(pl.name),
              centerTitle: true,
            ),
            body: pl.videos.isEmpty
                ? const Center(
                    child: Text('No videos in this playlist',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
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
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(v.channelTitle,
                            style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          onPressed: () =>
                              PlaylistService.instance.removeVideo(pl.id, v.id),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => YouTubePlayerScreen(
                              video: YouTubeVideo(
                                id: v.id,
                                title: v.title,
                                description: '',
                                thumbnailUrl: v.thumbnailUrl,
                                publishedAt: DateTime.now(),
                              ),
                              channelTitle: v.channelTitle,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
