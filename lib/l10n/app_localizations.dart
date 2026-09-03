import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('he', ''), // Hebrew
    Locale('en', ''), // English
  ];

  // Translations
  static final Map<String, Map<String, String>> _localizedValues = {
    'he': {
      'app_title': "My YT Music",
      'series': 'סדרות',
      'all_series': 'כל הסדרות',
      'new_lessons': 'שיעורים חדשים',
      'popular_series': 'סדרות פופולריות',
      'lessons': 'שיעורים',
      'lesson': 'שיעור',
      'error': 'שגיאה',
      'try_again': 'נסה שוב',
      'loading': 'טוען...',
      'video': 'וידאו',
      'audio': 'שמע',
      'play': 'נגן',
      'pause': 'השהה',
      'loaded_from_cache': 'נטען מהמטמון',
      'series_not_found': 'סדרה לא נמצאה',
      'lesson_not_found': 'שיעור לא נמצא',
      'network_error': 'שגיאת רשת',
      'search_series': 'חפש סדרות...',
      'search_lessons': 'חפש שיעורים...',
      'search_videos': 'חפש סרטונים...',
      'search_all_sources': 'חפש בכל המקורות...',
      'type_to_search': 'הקלד לפחות 2 תווים לחיפוש',
      'results': 'תוצאות',
      'no_results': 'לא נמצאו תוצאות',
      'select_source': 'My YT Channels',
      'coming_soon': 'בקרוב',
      'more_apps_from_developer': 'More from this developer',
      'playback_speed': 'מהירות ניגון:',
    },
    'en': {
      'app_title': 'Tora of Eretz Israel',
      'series': 'Series',
      'all_series': 'All Series',
      'new_lessons': 'New Lessons',
      'popular_series': 'Popular Series',
      'lessons': 'Lessons',
      'lesson': 'Lesson',
      'error': 'Error',
      'try_again': 'Try Again',
      'loading': 'Loading...',
      'video': 'Video',
      'audio': 'Audio',
      'play': 'Play',
      'pause': 'Pause',
      'loaded_from_cache': 'Loaded from cache',
      'series_not_found': 'Series not found',
      'lesson_not_found': 'Lesson not found',
      'network_error': 'Network error',
      'search_series': 'Search series...',
      'search_lessons': 'Search lessons...',
      'search_videos': 'Search videos...',
      'search_all_sources': 'Search all sources...',
      'type_to_search': 'Type at least 2 characters to search',
      'results': 'results',
      'no_results': 'No results found',
      'select_source': 'My YT Channels',
      'coming_soon': 'Coming Soon',
      'more_apps_from_developer': 'More apps from this developer',
      'playback_speed': 'Playback Speed:',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Getters for easy access
  String get appTitle => translate('app_title');
  String get series => translate('series');
  String get allSeries => translate('all_series');
  String get newLessons => translate('new_lessons');
  String get popularSeries => translate('popular_series');
  String get lessons => translate('lessons');
  String get lesson => translate('lesson');
  String get error => translate('error');
  String get tryAgain => translate('try_again');
  String get loading => translate('loading');
  String get video => translate('video');
  String get audio => translate('audio');
  String get play => translate('play');
  String get pause => translate('pause');
  String get loadedFromCache => translate('loaded_from_cache');
  String get seriesNotFound => translate('series_not_found');
  String get lessonNotFound => translate('lesson_not_found');
  String get networkError => translate('network_error');

  // Helper for lesson count
  String lessonCount(int count) {
    if (locale.languageCode == 'he') {
      return '$count שיעורים';
    } else {
      return '$count ${count == 1 ? 'Lesson' : 'Lessons'}';
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['he', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
