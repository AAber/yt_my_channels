import 'package:app_links/app_links.dart';
import 'saved_channels_service.dart';
import 'youtube_service.dart';
import 'dart:developer' as developer;

/// Encodes/decodes channel lists as deeplinks.
///
/// URL format:
///   https://myyt.isaac770.live/?channels=ID1,ID2&titles=Sia,Taylor%20Swift
///
/// Tapping the link:
///   - App installed  → app_links fires the URI into [handleIncomingLink]
///   - App not installed → App Store / Play Store, then on first launch
///     [checkInitialLink] reads the deferred URI (iOS only via Universal Links;
///     Android via App Links).
class DeeplinkService {
  static const _base = 'https://myyt.isaac770.live/';

  static DeeplinkService? _instance;
  static DeeplinkService get instance => _instance ??= DeeplinkService._();
  DeeplinkService._();

  final _appLinks = AppLinks();

  /// Call once from main() after SavedChannelsService.load().
  /// Returns the channels encoded in the initial link, if any.
  Future<List<SavedChannel>?> checkInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) return _parse(uri);
    } catch (e) {
      developer.log('DeeplinkService: initial link error $e');
    }
    return null;
  }

  /// Stream of incoming links while the app is running.
  Stream<List<SavedChannel>> get incomingChannels =>
      _appLinks.uriLinkStream
          .asyncMap(_parse)
          .where((list) => list != null)
          .cast<List<SavedChannel>>();

  /// Builds a shareable URL encoding [channels].
  static String buildShareUrl(List<SavedChannel> channels) {
    final ids    = channels.map((c) => c.id).join(',');
    final titles = channels.map((c) => Uri.encodeComponent(c.title)).join(',');
    final avatars = channels.map((c) => Uri.encodeComponent(c.avatarUrl)).join(',');
    return '$_base?channels=$ids&titles=$titles&avatars=$avatars';
  }

  /// Parses a URI and resolves channels from it.
  /// Titles + avatars come from the URL so no API call is needed.
  Future<List<SavedChannel>?> _parse(Uri uri) async {
    final ids    = uri.queryParameters['channels']?.split(',') ?? [];
    final titles = uri.queryParameters['titles']
        ?.split(',')
        .map(Uri.decodeComponent)
        .toList() ?? [];
    final avatars = uri.queryParameters['avatars']
        ?.split(',')
        .map(Uri.decodeComponent)
        .toList() ?? [];

    if (ids.isEmpty) return null;

    final channels = <SavedChannel>[];
    for (var i = 0; i < ids.length; i++) {
      final id    = ids[i].trim();
      final title = i < titles.length  ? titles[i]  : id;
      final avatar = i < avatars.length ? avatars[i] : '';
      if (id.isNotEmpty) {
        channels.add(SavedChannel(id: id, title: title, avatarUrl: avatar));
      }
    }

    developer.log('DeeplinkService: parsed ${channels.length} channels from link');
    return channels.isEmpty ? null : channels;
  }

  /// Resolves channels from a raw share URL string (for testing / manual paste).
  Future<List<SavedChannel>?> parseUrl(String url) async {
    try {
      return _parse(Uri.parse(url));
    } catch (_) {
      return null;
    }
  }
}
