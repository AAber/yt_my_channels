import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import '../l10n/language_provider.dart';
import '../services/download_service.dart';

class OfflineLibraryScreen extends StatefulWidget {
  const OfflineLibraryScreen({super.key});

  @override
  State<OfflineLibraryScreen> createState() => _OfflineLibraryScreenState();
}

class _OfflineLibraryScreenState extends State<OfflineLibraryScreen> {
  List<DownloadedFile> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final files = await DownloadService.listDownloads();
    if (mounted) setState(() { _files = files; _loading = false; });
  }

  Future<void> _delete(DownloadedFile f) async {
    await DownloadService.delete(f.filePath);
    await _load();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isHebrew = Provider.of<LanguageProvider>(context, listen: false)
            .locale.languageCode == 'he';

    return Scaffold(
      appBar: AppBar(
        title: Text(isHebrew ? 'מדיה שמורה' : 'Saved Media'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: isHebrew ? null : const BackButton(),
        actions: isHebrew ? [const BackButton()] : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(
                  child: Text(
                    isHebrew ? 'אין קבצים שמורים' : 'No saved files',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  itemCount: _files.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final f = _files[i];
                    return ListTile(
                      leading: Icon(
                        f.type == DownloadType.mp4
                            ? Icons.video_file
                            : Icons.audio_file,
                        color: const Color(0xFF1976D2),
                        size: 32,
                      ),
                      title: Text(f.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${f.type == DownloadType.mp4 ? 'MP4' : 'MP3'} · ${_formatSize(f.sizeBytes)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        onPressed: () => _delete(f),
                      ),
                      onTap: () async {
                        if (f.type == DownloadType.mp3) {
                          final result = await OpenFile.open(f.filePath, type: 'audio/mpeg');
                          if (result.type != ResultType.done && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message)));
                          }
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _OfflinePlayerScreen(file: f),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline player — plays local file
// ---------------------------------------------------------------------------

class _OfflinePlayerScreen extends StatefulWidget {
  final DownloadedFile file;
  const _OfflinePlayerScreen({required this.file});

  @override
  State<_OfflinePlayerScreen> createState() => _OfflinePlayerScreenState();
}

class _OfflinePlayerScreenState extends State<_OfflinePlayerScreen> {
  VideoPlayerController? _video;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _video = VideoPlayerController.file(File(widget.file.filePath));
      await _video!.initialize();
      _video!.addListener(() { if (mounted) setState(() {}); });
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load media: $e')));
      }
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isHebrew = Provider.of<LanguageProvider>(context, listen: false)
            .locale.languageCode == 'he';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: isHebrew ? null : const BackButton(),
        actions: isHebrew ? [const BackButton()] : null,
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _buildVideo(),
    );
  }

  Widget _buildVideo() {
    final pos = _video!.value.position;
    final dur = _video!.value.duration;
    final progress =
        dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _video!.value.aspectRatio,
          child: VideoPlayer(_video!),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (v) => _video!.seekTo(
                      Duration(milliseconds: (v * dur.inMilliseconds).round())),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(pos),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(_fmt(dur),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            _video!.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
            size: 56,
          ),
          onPressed: () => setState(() {
            _video!.value.isPlaying ? _video!.pause() : _video!.play();
          }),
        ),
      ],
    );
  }

}
