import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'l10n/app_localizations.dart';
import 'l10n/language_provider.dart';
import 'screens/source_selection_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'live.isaac770.israel.audio',
    androidNotificationChannelName: 'תורת ישראל',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );
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
          title: 'תורת ארץ ישראל',
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
