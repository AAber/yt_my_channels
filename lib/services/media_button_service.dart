import 'package:flutter/services.dart';

typedef MediaButtonCallback = void Function(String action);

class MediaButtonService {
  MediaButtonService._();
  static final MediaButtonService instance = MediaButtonService._();

  static const _channel = MethodChannel('media_buttons');
  MediaButtonCallback? _callback;

  void init() {
    _channel.setMethodCallHandler((call) async {
      _callback?.call(call.method);
    });
  }

  void register(MediaButtonCallback cb) => _callback = cb;
  void unregister() => _callback = null;
}
