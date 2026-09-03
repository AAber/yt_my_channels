import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:developer' as developer;
import 'l10n/app_localizations.dart';
import 'l10n/language_provider.dart';
import 'screens/channel_picker_screen.dart';
import 'screens/source_selection_screen.dart';
import 'services/saved_channels_service.dart';
import 'services/deeplink_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  developer.log('▶ main() start', name: 'APP_INIT');

  try {
    await Hive.initFlutter();
    developer.log('✓ Hive ready', name: 'APP_INIT');
  } catch (e, st) {
    developer.log('✗ Hive failed: $e', name: 'APP_INIT', error: e, stackTrace: st);
  }

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'live.isaac770.yt_my_channels.audio',
      androidNotificationChannelName: 'yt_my_channels',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
    developer.log('✓ JustAudioBackground ready', name: 'APP_INIT');
  } catch (e, st) {
    developer.log('✗ JustAudioBackground failed: $e', name: 'APP_INIT', error: e, stackTrace: st);
  }

  // Load saved channels before deciding which screen to show
  await SavedChannelsService.instance.load();

  // Check if app was opened via a share deeplink
  final linkedChannels = await DeeplinkService.instance.checkInitialLink();
  if (linkedChannels != null && linkedChannels.isNotEmpty) {
    for (final ch in linkedChannels) {
      await SavedChannelsService.instance.add(ch);
    }
    developer.log('✓ Deeplink: loaded ${linkedChannels.length} channels', name: 'APP_INIT');
  }
  developer.log('✓ SavedChannels: ${SavedChannelsService.instance.channels.length} channels', name: 'APP_INIT');

  developer.log('▶ runApp()', name: 'APP_INIT');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider.value(value: SavedChannelsService.instance),
      ],
      child: const MyYTApp(),
    ),
  );
}

class MyYTApp extends StatelessWidget {
  const MyYTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        // Route: first launch → ChannelPickerScreen, returning user → SourceSelectionScreen
        final home = SavedChannelsService.instance.isEmpty
            ? const ChannelPickerScreen()
            : const SourceSelectionScreen();

        return MaterialApp(
          title: 'My YT Music',
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
              textDirection: languageProvider.locale.languageCode == 'en'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: child!,
            );
          },
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0A0A0F),
            primaryColor: const Color(0xFFE53935),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE53935),
              brightness: Brightness.dark,
              surface: const Color(0xFF12121A),
              onSurface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0A0A0F),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1A1A26),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1A1A26),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
              ),
              hintStyle: TextStyle(color: Colors.white38),
              prefixIconColor: Colors.white38,
            ),
          ),
          home: home,
        );
      },
    );
  }
}
