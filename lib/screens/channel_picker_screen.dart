import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/saved_channels_service.dart';
import '../services/youtube_service.dart';
import 'source_selection_screen.dart';

class ChannelPickerScreen extends StatefulWidget {
  /// When true the screen is opened from the + button (already has channels).
  final bool isAddMode;
  const ChannelPickerScreen({super.key, this.isAddMode = false});

  @override
  State<ChannelPickerScreen> createState() => _ChannelPickerScreenState();
}

class _ChannelPickerScreenState extends State<ChannelPickerScreen> {
  final _service = SavedChannelsService.instance;
  final _ytService = YouTubeService();
  final _inputController = TextEditingController();

  bool _loading = false;
  String? _error;
  // Channels staged in this session (not yet committed)
  final List<SavedChannel> _staged = [];

  @override
  void initState() {
    super.initState();
    // Pre-populate staged with already-saved channels so user sees current state
    _staged.addAll(_service.channels);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  bool get _canProceed => _staged.isNotEmpty;
  bool get _atMax => _staged.length >= SavedChannelsService.maxChannels;

  Future<void> _addChannel() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;
    if (_atMax) {
      _setError('Maximum ${SavedChannelsService.maxChannels} channels reached.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final channel = await _ytService.fetchChannelInfo(input);
      if (channel == null) {
        _setError('Channel not found. Try a YouTube URL, @handle, or channel ID.');
        return;
      }
      if (_staged.any((c) => c.id == channel.id)) {
        _setError('"${channel.title}" is already in your list.');
        return;
      }
      setState(() {
        _staged.add(channel);
        _inputController.clear();
        _error = null;
      });
    } catch (e) {
      developer.log('ChannelPicker: add error $e');
      _setError('Could not resolve channel. Check your internet connection.');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _removeStaged(SavedChannel ch) => setState(() => _staged.remove(ch));

  void _setError(String msg) => setState(() { _error = msg; _loading = false; });

  Future<void> _proceed() async {
    // Persist: remove channels no longer in staged, add new ones
    final existing = _service.channels.toList();
    for (final ch in existing) {
      if (!_staged.contains(ch)) await _service.remove(ch.id);
    }
    for (final ch in _staged) {
      await _service.add(ch);
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SourceSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = SavedChannelsService.maxChannels - _staged.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAddMode ? 'Manage Channels' : 'Choose Your Channels'),
        centerTitle: true,
        automaticallyImplyLeading: widget.isAddMode,
      ),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          if (!widget.isAddMode)
            Container(
              width: double.infinity,
              color: theme.colorScheme.primaryContainer,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome! Pick your favourite YouTube channels.',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Paste a YouTube URL, @handle, or channel ID below.\n'
                    'Select 1–${SavedChannelsService.maxChannels} channels to get started.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          // ── Input row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: !_atMax,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _addChannel(),
                    decoration: InputDecoration(
                      hintText: _atMax
                          ? 'Max ${SavedChannelsService.maxChannels} channels reached'
                          : 'youtube.com/@handle  or  UC...',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (_loading || _atMax) ? null : _addChannel,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add),
                ),
              ],
            ),
          ),

          // ── Error ────────────────────────────────────────────────────────
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
            ),

          // ── Counter ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_staged.length} / ${SavedChannelsService.maxChannels} channels selected',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                if (remaining > 0 && _staged.isNotEmpty)
                  Text(
                    '  ·  $remaining more allowed',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Staged channel list ──────────────────────────────────────────
          Expanded(
            child: _staged.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.subscriptions_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No channels yet.\nAdd one above to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _staged.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final ch = _staged.removeAt(oldIndex);
                        _staged.insert(newIndex, ch);
                      });
                    },
                    itemBuilder: (context, index) {
                      final ch = _staged[index];
                      return _ChannelTile(
                        key: ValueKey(ch.id),
                        channel: ch,
                        onRemove: () => _removeStaged(ch),
                      );
                    },
                  ),
          ),

          // ── Proceed button ───────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canProceed ? _proceed : null,
                  icon: const Icon(Icons.check),
                  label: Text(widget.isAddMode ? 'Save Changes' : 'Continue to App'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final SavedChannel channel;
  final VoidCallback onRemove;
  const _ChannelTile({super.key, required this.channel, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: channel.avatarUrl.isNotEmpty
            ? NetworkImage(channel.avatarUrl)
            : null,
        child: channel.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
      ),
      title: Text(channel.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(channel.id, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: onRemove,
            tooltip: 'Remove',
          ),
          const Icon(Icons.drag_handle, color: Colors.grey),
        ],
      ),
    );
  }
}
