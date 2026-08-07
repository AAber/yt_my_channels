import 'package:just_audio/just_audio.dart';

/// Single long-lived [AudioPlayer] — [just_audio_background] allows only one
/// instance, and disposing while native events are still in flight crashes with
/// "Cannot add new events after calling close".
class AudioPlayerService {
  AudioPlayerService._();
  static final AudioPlayerService instance = AudioPlayerService._();

  AudioPlayer? _player;

  AudioPlayer? get current => _player;

  Future<AudioPlayer> acquire() async {
    _player ??= AudioPlayer();
    final player = _player!;
    if (player.processingState != ProcessingState.idle) {
      try {
        await player.stop();
        await player.processingStateStream
            .firstWhere((s) => s == ProcessingState.idle)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Timed out — dispose and recreate to guarantee a clean state
        try { await player.dispose(); } catch (_) {}
        _player = AudioPlayer();
      }
    }
    return _player!;
  }

  /// Stops playback but keeps the player alive for reuse.
  Future<void> stop() async {
    final player = _player;
    if (player == null) return;
    try {
      if (player.processingState != ProcessingState.idle) {
        await player.stop();
        await player.processingStateStream
            .firstWhere((s) => s == ProcessingState.idle)
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
  }
}
