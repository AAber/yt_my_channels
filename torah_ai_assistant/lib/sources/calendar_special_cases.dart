/// Known Sefaria calendar item titles (English) — extend for new special cases.
///
/// Full API output is logged by [SefariaCalendarSnapshot.logForDevelopers] after
/// each fetch so you can add entries here and in [SefariaCalendarSnapshot].
class CalendarSpecialCases {
  CalendarSpecialCases._();

  /// Our internal case id → Sefaria `calendar_items[].title.en`
  static const Map<String, String> sefariaTitleEn = {
    parshaWeekly: 'Parashat Hashavua',
    dafYomi: 'Daf Yomi',
    haftarah: 'Haftarah',
    dailyMishnah: 'Daily Mishnah',
    dailyRambam: 'Daily Rambam',
    dafAWeek: 'Daf a Week',
  };

  static const String parshaWeekly = 'parsha_weekly';
  static const String dafYomi = 'daf_yomi';
  static const String haftarah = 'haftarah';
  static const String dailyMishnah = 'daily_mishnah';
  static const String dailyRambam = 'daily_rambam';
  static const String dafAWeek = 'daf_a_week';

  /// Cases resolved via Sefaria calendar + injected into search/LLM today.
  static const Set<String> implemented = {parshaWeekly, dafYomi};
}
