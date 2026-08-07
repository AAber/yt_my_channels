import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:developer' as developer;
import 'l10n/app_localizations.dart';
import 'l10n/language_provider.dart';
import 'screens/source_selection_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  developer.log('▶ main() start', name: 'APP_INIT');

  try {
    developer.log('▶ Hive.initFlutter()', name: 'APP_INIT');
    await Hive.initFlutter();
    developer.log('✓ Hive ready', name: 'APP_INIT');
  } catch (e, st) {
    developer.log('✗ Hive failed: $e', name: 'APP_INIT', error: e, stackTrace: st);
  }

  try {
    developer.log('▶ JustAudioBackground.init()', name: 'APP_INIT');
    await JustAudioBackground.init(
      androidNotificationChannelId: 'live.isaac770.israel.audio',
      androidNotificationChannelName: 'yt_my_channels',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
    developer.log('✓ JustAudioBackground ready', name: 'APP_INIT');
  } catch (e, st) {
    developer.log('✗ JustAudioBackground failed: $e', name: 'APP_INIT', error: e, stackTrace: st);
    // Continue — audio background is non-fatal for UI
  }

  developer.log('▶ runApp()', name: 'APP_INIT');
  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: const DavidApp(),
    ),
  );
}

class DavidApp extends StatelessWidget {
  const DavidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          title: "My YT Music",
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: languageProvider.locale,
          builder: (context, child) {
            return Directionality(
              textDirection: languageProvider.locale.languageCode == 'he'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: child!,
            );
          },
          theme: ThemeData(
            primarySwatch: Colors.blue,
            primaryColor: const Color(0xFF1976D2),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1976D2),
              brightness: Brightness.light,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1976D2),
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            useMaterial3: true,
          ),
          home: const SourceSelectionScreen(),
        );
      },
    );
  }
}
