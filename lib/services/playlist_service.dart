import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'youtube_service.dart';

class PlaylistVideo {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String channelTitle;

  const PlaylistVideo({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.channelTitle,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'channelTitle': channelTitle,
      };

  factory PlaylistVideo.fromJson(Map<String, dynamic> j) => PlaylistVideo(
        id: j['id'] as String,
        title: j['title'] as String,
        thumbnailUrl: j['thumbnailUrl'] as String,
        channelTitle: j['channelTitle'] as String,
      );

  factory PlaylistVideo.fromYouTubeVideo(YouTubeVideo v, String channelTitle) =>
      PlaylistVideo(
        id: v.id,
        title: v.title,
        thumbnailUrl: v.thumbnailUrl,
        channelTitle: channelTitle,
      );
}

class Playlist {
  final String id;
  final String name;
  final List<PlaylistVideo> videos;

  Playlist({required this.id, required this.name, List<PlaylistVideo>? videos})
      : videos = videos ?? [];

  Playlist copyWith({String? name, List<PlaylistVideo>? videos}) =>
      Playlist(id: id, name: name ?? this.name, videos: videos ?? this.videos);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'videos': videos.map((v) => v.toJson()).toList(),
      };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: j['name'] as String,
        videos: (j['videos'] as List)
            .map((e) => PlaylistVideo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PlaylistService extends ChangeNotifier {
  static const _key = 'yt_playlists';

  static PlaylistService? _instance;
  PlaylistService._();
  static PlaylistService get instance => _instance ??= PlaylistService._();

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => List.unmodifiable(_playlists);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = json.decode(raw) as List;
      _playlists =
          list.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
      developer.log('PlaylistService: loaded ${_playlists.length} playlists');
    } catch (e) {
      developer.log('PlaylistService: load error $e');
    }
  }

  Future<Playlist> createPlaylist(String name) async {
    final pl = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    _playlists.add(pl);
    notifyListeners();
    await _save();
    return pl;
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    await _save();
  }

  Future<void> addVideo(String playlistId, PlaylistVideo video) async {
    final i = _playlists.indexWhere((p) => p.id == playlistId);
    if (i == -1) return;
    final pl = _playlists[i];
    if (pl.videos.any((v) => v.id == video.id)) return;
    _playlists[i] = pl.copyWith(videos: [...pl.videos, video]);
    notifyListeners();
    await _save();
  }

  Future<void> removeVideo(String playlistId, String videoId) async {
    final i = _playlists.indexWhere((p) => p.id == playlistId);
    if (i == -1) return;
    final pl = _playlists[i];
    _playlists[i] =
        pl.copyWith(videos: pl.videos.where((v) => v.id != videoId).toList());
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, json.encode(_playlists.map((p) => p.toJson()).toList()));
  }
}
