import 'package:flutter/material.dart';
import '../services/playlist_service.dart';

/// Shows a bottom sheet to add [video] to an existing or new playlist.
/// Returns the playlist the video was added to, or null if dismissed.
Future<Playlist?> showAddToPlaylistSheet(
    BuildContext context, PlaylistVideo video) {
  return showModalBottomSheet<Playlist>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AddToPlaylistSheet(video: video),
  );
}

class _AddToPlaylistSheet extends StatefulWidget {
  final PlaylistVideo video;
  const _AddToPlaylistSheet({required this.video});

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  final _service = PlaylistService.instance;
  final _nameController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addToPlaylist(Playlist pl) async {
    await _service.addVideo(pl.id, widget.video);
    if (mounted) Navigator.pop(context, pl);
  }

  Future<void> _createAndAdd() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final pl = await _service.createPlaylist(name);
    await _service.addVideo(pl.id, widget.video);
    if (mounted) Navigator.pop(context, pl);
  }

  @override
  Widget build(BuildContext context) {
    final playlists = _service.playlists;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Add to playlist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('No playlists yet — create one below.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (_, i) {
                  final pl = playlists[i];
                  final alreadyAdded = pl.videos.any((v) => v.id == widget.video.id);
                  return ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: Text(pl.name),
                    subtitle: Text('${pl.videos.length} videos'),
                    trailing: alreadyAdded
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: alreadyAdded ? null : () => _addToPlaylist(pl),
                  );
                },
              ),
            ),
          const Divider(height: 1),
          if (_creating)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Playlist name',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _createAndAdd(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: _createAndAdd, child: const Text('Create')),
                ],
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New playlist'),
              onTap: () => setState(() => _creating = true),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
