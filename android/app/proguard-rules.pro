# Flutter-specific rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.embedding.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Required by the Flutter team to analyze Flutter apps.
-keep class com.google.common.util.concurrent.ListenableFuture { *; }

# Flutter deferred components.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# just_audio_background / AudioService
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

# youtube_player_flutter / WebView
-keep class com.google.android.youtube.** { *; }
-dontwarn com.google.android.youtube.**
