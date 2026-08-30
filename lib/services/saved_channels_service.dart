import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class SavedChannel {
  final String id;
  final String title;
  final String avatarUrl; // network URL — fetched from YouTube

  const SavedChannel({
    required this.id,
    required this.title,
    required this.avatarUrl,
  });

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'avatarUrl': avatarUrl};

  factory SavedChannel.fromJson(Map<String, dynamic> j) => SavedChannel(
        id: j['id'] as String,
        title: j['title'] as String,
        avatarUrl: j['avatarUrl'] as String,
      );

  @override
  bool operator ==(Object other) => other is SavedChannel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class SavedChannelsService {
  static const _key = 'saved_yt_channels';
  static const int maxChannels = 8;

  static SavedChannelsService? _instance;
  SavedChannelsService._();
  static SavedChannelsService get instance => _instance ??= SavedChannelsService._();

  List<SavedChannel> _channels = [];
  List<SavedChannel> get channels => List.unmodifiable(_channels);
  bool get isEmpty => _channels.isEmpty;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) { _channels = []; return; }
      final list = json.decode(raw) as List;
      _channels = list.map((e) => SavedChannel.fromJson(e as Map<String, dynamic>)).toList();
      developer.log('SavedChannelsService: loaded ${_channels.length} channels');
    } catch (e) {
      developer.log('SavedChannelsService: load error $e');
      _channels = [];
    }
  }

  Future<void> add(SavedChannel channel) async {
    developer.log('SavedChannelsService.add() called for: ${channel.title} (${channel.id})');
    if (_channels.any((c) => c.id == channel.id)) {
      developer.log('Channel already exists in list, skipping add');
      return;
    }
    if (_channels.length >= maxChannels) {
      developer.log('Max channels reached, skipping add');
      return;
    }
    _channels.add(channel);
    developer.log('Channel added to local list, saving...');
    await _save();
    developer.log('Channel saved successfully');
  }

  Future<void> remove(String channelId) async {
    _channels.removeWhere((c) => c.id == channelId);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(_channels.map((c) => c.toJson()).toList()));
  }
}
