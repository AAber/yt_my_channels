import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_special_cases.dart';

/// One row from Sefaria `calendar_items` — keep raw map for future special cases.
class CalendarItem {
  final String titleEn;
  final String? titleHe;
  final String? displayEn;
  final String? displayHe;
  final String? ref;
  final String? url;
  final Map<String, dynamic> raw;

  const CalendarItem({
    required this.titleEn,
    this.titleHe,
    this.displayEn,
    this.displayHe,
    this.ref,
    this.url,
    required this.raw,
  });

  factory CalendarItem.fromStored(Map<String, dynamic> json) => CalendarItem(
        titleEn: json['titleEn']?.toString() ?? '',
        titleHe: json['titleHe']?.toString(),
        displayEn: json['displayEn']?.toString(),
        displayHe: json['displayHe']?.toString(),
        ref: json['ref']?.toString(),
        url: json['url']?.toString(),
        raw: Map<String, dynamic>.from(
          json['raw'] as Map? ?? {},
        ),
      );

  factory CalendarItem.fromApi(Map<String, dynamic> raw) {
    final title = raw['title'];
    return CalendarItem(
      titleEn: _mapStr(title, 'en') ?? title?.toString() ?? '',
      titleHe: _mapStr(title, 'he'),
      displayEn: _mapStr(raw['displayValue'], 'en'),
      displayHe: _mapStr(raw['displayValue'], 'he'),
      ref: raw['ref']?.toString(),
      url: raw['url']?.toString(),
      raw: Map<String, dynamic>.from(raw),
    );
  }

  static String? _mapStr(dynamic v, String key) {
    if (v is Map) return v[key]?.toString();
    return null;
  }

  Map<String, dynamic> toJson() => {
        'titleEn': titleEn,
        'titleHe': titleHe,
        'displayEn': displayEn,
        'displayHe': displayHe,
        'ref': ref,
        'url': url,
        'raw': raw,
      };
}

class WeeklyParsha {
  final String hebrewName;
  final String englishName;
  final String ref;
  final String? url;
  final String? haftarahRef;
  final String? haftarahHebrew;
  final CalendarItem? sourceItem;

  const WeeklyParsha({
    required this.hebrewName,
    required this.englishName,
    required this.ref,
    this.url,
    this.haftarahRef,
    this.haftarahHebrew,
    this.sourceItem,
  });

  bool get isResolved => hebrewName.isNotEmpty;

  String toContextBlock() {
    final lines = <String>[
      'פרשת השבוע (לפי לוח ספריא): פרשת $hebrewName',
      if (englishName.isNotEmpty) 'שם באנגלית: $englishName',
      'טווח קריאה: $ref',
    ];
    if (haftarahHebrew != null && haftarahHebrew!.isNotEmpty) {
      lines.add('הפטרה: $haftarahHebrew');
    }
    return lines.join('\n');
  }

  Map<String, dynamic> toJson() => {
        'hebrewName': hebrewName,
        'englishName': englishName,
        'ref': ref,
        'url': url,
        'haftarahRef': haftarahRef,
        'haftarahHebrew': haftarahHebrew,
      };

  factory WeeklyParsha.fromJson(Map<String, dynamic> json) => WeeklyParsha(
        hebrewName: json['hebrewName']?.toString() ?? '',
        englishName: json['englishName']?.toString() ?? '',
        ref: json['ref']?.toString() ?? '',
        url: json['url']?.toString(),
        haftarahRef: json['haftarahRef']?.toString(),
        haftarahHebrew: json['haftarahHebrew']?.toString(),
      );
}

/// Today's Daf Yomi from Sefaria calendars API.
class DafYomi {
  final String hebrewDisplay;
  final String englishDisplay;
  final String ref;
  final String? url;
  final String? tractateHe;
  final String? tractateEn;
  final CalendarItem? sourceItem;

  const DafYomi({
    required this.hebrewDisplay,
    required this.englishDisplay,
    required this.ref,
    this.url,
    this.tractateHe,
    this.tractateEn,
    this.sourceItem,
  });

  bool get isResolved => ref.isNotEmpty || hebrewDisplay.isNotEmpty;

  String toContextBlock() {
    return [
      'דף יומי (לפי לוח ספריא): $hebrewDisplay',
      if (englishDisplay.isNotEmpty) 'שם באנגלית: $englishDisplay',
      'מקור: $ref',
    ].join('\n');
  }

  /// Terms to search lesson catalogs (Meir / David).
  List<String> searchTerms() {
    final terms = <String>['דף יומי', 'דף יומיי'];
    if (tractateHe != null && tractateHe!.isNotEmpty) terms.add(tractateHe!);
    if (tractateEn != null && tractateEn!.isNotEmpty) {
      final tractate = tractateEn!.split(RegExp(r'\s+')).first;
      if (tractate.isNotEmpty) terms.add(tractate);
    }
    if (hebrewDisplay.isNotEmpty) terms.add(hebrewDisplay);
    return terms.toSet().toList();
  }

  Map<String, dynamic> toJson() => {
        'hebrewDisplay': hebrewDisplay,
        'englishDisplay': englishDisplay,
        'ref': ref,
        'url': url,
        'tractateHe': tractateHe,
        'tractateEn': tractateEn,
      };

  factory DafYomi.fromJson(Map<String, dynamic> json) => DafYomi(
        hebrewDisplay: json['hebrewDisplay']?.toString() ?? '',
        englishDisplay: json['englishDisplay']?.toString() ?? '',
        ref: json['ref']?.toString() ?? '',
        url: json['url']?.toString(),
        tractateHe: json['tractateHe']?.toString(),
        tractateEn: json['tractateEn']?.toString(),
      );
}

/// Full Sefaria /api/calendars response — use [logForDevelopers] to inspect all items.
class SefariaCalendarSnapshot {
  final DateTime fetchedAt;
  final bool diaspora;
  final List<CalendarItem> allItems;
  final WeeklyParsha? weeklyParsha;
  final DafYomi? dafYomi;
  final Map<String, dynamic> rawApi;

  const SefariaCalendarSnapshot({
    required this.fetchedAt,
    required this.diaspora,
    required this.allItems,
    this.weeklyParsha,
    this.dafYomi,
    required this.rawApi,
  });

  /// Every item keyed by English title (for adding new special cases).
  Map<String, CalendarItem> get itemsByTitleEn {
    final map = <String, CalendarItem>{};
    for (final item in allItems) {
      if (item.titleEn.isNotEmpty) map[item.titleEn] = item;
    }
    return map;
  }

  /// Combined LLM context for all resolved special cases.
  String toContextBlock() {
    final parts = <String>[];
    if (weeklyParsha != null && weeklyParsha!.isResolved) {
      parts.add(weeklyParsha!.toContextBlock());
    }
    if (dafYomi != null && dafYomi!.isResolved) {
      parts.add(dafYomi!.toContextBlock());
    }
    return parts.join('\n\n');
  }

  /// Pretty-print full API output — use when adding cases in [CalendarSpecialCases].
  void logForDevelopers() {
    final summary = allItems
        .map((i) => '  • ${i.titleEn}: he=${i.displayHe} en=${i.displayEn} ref=${i.ref}')
        .join('\n');
    print('📅 ========== Sefaria Calendar API ==========');
    print('📅 diaspora=$diaspora fetchedAt=$fetchedAt');
    print('📅 Parsed items (${allItems.length}):\n$summary');
    print('📅 Implemented: parsha=${weeklyParsha?.hebrewName} daf=${dafYomi?.hebrewDisplay}');
    print('📅 Full JSON (calendar_items + keys):');
    const encoder = JsonEncoder.withIndent('  ');
    try {
      print(encoder.convert(rawApi));
    } catch (_) {
      print(rawApi.toString());
    }
    print('📅 ==========================================');
  }

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'diaspora': diaspora,
        'allItems': allItems.map((e) => e.toJson()).toList(),
        'weeklyParsha': weeklyParsha?.toJson(),
        'dafYomi': dafYomi?.toJson(),
        'rawApi': rawApi,
      };

  factory SefariaCalendarSnapshot.fromJson(Map<String, dynamic> json) {
    final items = (json['allItems'] as List? ?? [])
        .map((e) => CalendarItem.fromStored(e as Map<String, dynamic>))
        .toList();
    return SefariaCalendarSnapshot(
      fetchedAt: DateTime.tryParse(json['fetchedAt']?.toString() ?? '') ??
          DateTime.now(),
      diaspora: json['diaspora'] == true,
      allItems: items,
      weeklyParsha: json['weeklyParsha'] != null
          ? WeeklyParsha.fromJson(
              json['weeklyParsha'] as Map<String, dynamic>,
            )
          : null,
      dafYomi: json['dafYomi'] != null
          ? DafYomi.fromJson(json['dafYomi'] as Map<String, dynamic>)
          : null,
      rawApi: json['rawApi'] as Map<String, dynamic>? ?? {},
    );
  }
}

class SefariaCalendar {
  static const _baseUrl = 'https://www.sefaria.org/api';
  static const _cacheKey = 'sefaria_calendar_snapshot';
  static const _cacheTsKey = 'sefaria_calendar_snapshot_ts';
  static const _cacheTtl = Duration(hours: 12);

  static Future<SefariaCalendarSnapshot?> fetchSnapshot({
    bool diaspora = false,
    bool logOutput = true,
  }) async {
    try {
      final cached = await _readCache();
      if (cached != null) {
        if (logOutput) cached.logForDevelopers();
        return cached;
      }

      final url = '$_baseUrl/calendars?diaspora=${diaspora ? 1 : 0}';
      print('📅 SefariaCalendar: GET $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('📅 SefariaCalendar: HTTP ${response.statusCode}');
        return null;
      }

      final rawApi =
          json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final snapshot = _parseSnapshot(rawApi, diaspora: diaspora);
      await _writeCache(snapshot);
      if (logOutput) snapshot.logForDevelopers();
      return snapshot;
    } catch (e, st) {
      print('📅 SefariaCalendar error: $e\n$st');
      return null;
    }
  }

  static Future<WeeklyParsha?> fetchWeeklyParsha({bool diaspora = false}) async {
    final snap = await fetchSnapshot(diaspora: diaspora, logOutput: false);
    return snap?.weeklyParsha;
  }

  static Future<DafYomi?> fetchDafYomi({bool diaspora = false}) async {
    final snap = await fetchSnapshot(diaspora: diaspora, logOutput: false);
    return snap?.dafYomi;
  }

  static SefariaCalendarSnapshot _parseSnapshot(
    Map<String, dynamic> rawApi, {
    required bool diaspora,
  }) {
    final items = <CalendarItem>[];
    for (final raw in rawApi['calendar_items'] as List? ?? []) {
      if (raw is Map<String, dynamic>) {
        items.add(CalendarItem.fromApi(raw));
      }
    }

    WeeklyParsha? parsha;
    DafYomi? daf;
    String? haftarahRef;
    String? haftarahHe;

    for (final item in items) {
      switch (item.titleEn) {
        case 'Parashat Hashavua':
          parsha = WeeklyParsha(
            hebrewName: item.displayHe ?? '',
            englishName: item.displayEn ?? '',
            ref: item.ref ?? '',
            url: item.url,
            sourceItem: item,
          );
          break;
        case 'Haftarah':
          if (haftarahRef == null) {
            haftarahRef = item.ref;
            haftarahHe = item.displayHe;
          }
          break;
        case 'Daf Yomi':
          daf = _parseDafYomi(item);
          break;
      }
    }

    if (parsha != null && haftarahRef != null) {
      parsha = WeeklyParsha(
        hebrewName: parsha.hebrewName,
        englishName: parsha.englishName,
        ref: parsha.ref,
        url: parsha.url,
        haftarahRef: haftarahRef,
        haftarahHebrew: haftarahHe,
        sourceItem: parsha.sourceItem,
      );
    }

    return SefariaCalendarSnapshot(
      fetchedAt: DateTime.now(),
      diaspora: diaspora,
      allItems: items,
      weeklyParsha: parsha,
      dafYomi: daf,
      rawApi: rawApi,
    );
  }

  static DafYomi _parseDafYomi(CalendarItem item) {
    final en = item.displayEn ?? item.ref ?? '';
    final he = item.displayHe ?? '';
    String? tractateEn;
    String? tractateHe;
    if (en.isNotEmpty) {
      tractateEn = en.split(RegExp(r'\s+')).first;
    }
    if (he.isNotEmpty) {
      tractateHe = he.split(RegExp(r'[\s׳"\u05F3]+')).first;
    }
    return DafYomi(
      hebrewDisplay: he.isNotEmpty ? he : en,
      englishDisplay: en,
      ref: item.ref ?? en,
      url: item.url,
      tractateHe: tractateHe,
      tractateEn: tractateEn,
      sourceItem: item,
    );
  }

  static bool needsCalendarFetch(
    Map<String, dynamic> intentJson,
    String userMessage,
  ) {
    return needsWeeklyResolution(intentJson, userMessage) ||
        needsDafYomiResolution(intentJson, userMessage);
  }

  static bool needsWeeklyResolution(
    Map<String, dynamic> intentJson,
    String userMessage,
  ) {
    final parsha = intentJson['parsha']?.toString().trim() ?? '';
    if (parsha == 'השבוע' || parsha.contains('השבוע')) return true;
    if (RegExp(
      r'פרשת\s+השבוע|פרשה\s+של\s+השבוע|פרשה\s+השבוע',
      caseSensitive: false,
    ).hasMatch(userMessage)) {
      return parsha.isEmpty || parsha == 'השבוע';
    }
    return false;
  }

  static bool needsDafYomiResolution(
    Map<String, dynamic> intentJson,
    String userMessage,
  ) {
    final daf = intentJson['daf_yomi']?.toString().trim() ?? '';
    if (daf == 'היום' || daf.contains('היום')) return true;
    if (RegExp(
      r'דף\s*יומי|דףיומי|daf\s*yomi',
      caseSensitive: false,
    ).hasMatch(userMessage)) {
      return daf.isEmpty || daf == 'היום';
    }
    return false;
  }

  static Future<SefariaCalendarSnapshot?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      final ts = prefs.getInt(_cacheTsKey);
      if (raw == null || ts == null) return null;
      if (DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(ts),
          ) >
          _cacheTtl) {
        return null;
      }
      return SefariaCalendarSnapshot.fromJson(
        json.decode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(SefariaCalendarSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(snapshot.toJson()));
      await prefs.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
