import 'package:flutter/foundation.dart';
import '../models/lesson.dart';

class LessonMediaResolver {
  Future<Lesson> resolve(Lesson lesson) async => lesson;

  Future<String?> resolveVideoUrl(Lesson lesson) async {
    if (lesson.hasMp4) {
      debugPrint('RESOLVER ✅ [${lesson.mp4Url}] → mp4');
      return lesson.mp4Url;
    }
    if (lesson.hasVimeo) {
      debugPrint('RESOLVER ✅ [${lesson.vimeoUrl}] → Vimeo (WebView)');
      return null;
    }
    debugPrint('RESOLVER ⚠️ no video URL for "${lesson.name}"');
    return null;
  }
}
