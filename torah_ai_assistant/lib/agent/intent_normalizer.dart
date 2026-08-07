/// Normalizes LLM intent JSON for calendar specials (פרשה, דף יומי, …).
class IntentNormalizer {
  static final _parshaInText = RegExp(
    r'פרשת\s+השבוע|פרשה|פרשת|פרשיות|parashat|parsha',
    caseSensitive: false,
  );

  static final _dafYomiInText = RegExp(
    r'דף\s*יומי|דףיומי|daf\s*yomi',
    caseSensitive: false,
  );

  static final _stripParshaPrefix = RegExp(r'^(פרשת|פרשה)\s+');
  static final _stripDafPrefix = RegExp(r'^(דף\s*יומי|דףיומי)\s*');

  static const _torahBooks = {
    'בראשית',
    'שמות',
    'ויקרא',
    'במדבר',
    'דברים',
  };

  static Map<String, dynamic> normalize(
    Map<String, dynamic> json,
    String userMessage,
  ) {
    var out = Map<String, dynamic>.from(json);
    out = _normalizeParsha(out, userMessage);
    out = _normalizeDafYomi(out, userMessage);
    return out;
  }

  static Map<String, dynamic> _normalizeParsha(
    Map<String, dynamic> json,
    String userMessage,
  ) {
    final out = Map<String, dynamic>.from(json);
    final combined = [
      userMessage,
      out['topic']?.toString() ?? '',
      out['parsha']?.toString() ?? '',
      out['book']?.toString() ?? '',
    ].join(' ');

    if (!_parshaInText.hasMatch(combined)) return out;

    final topic = out['topic']?.toString().trim();
    if (topic != null && topic.isNotEmpty && _isParshaPhrase(topic)) {
      out['parsha'] = _extractParshaName(topic) ?? 'השבוע';
      out['topic'] = null;
    }

    final parsha = out['parsha']?.toString().trim();
    if (parsha != null && parsha.isNotEmpty) {
      out['parsha'] = _extractParshaName(parsha) ?? 'השבוע';
    } else {
      out['parsha'] = _extractParshaName(userMessage) ?? 'השבוע';
    }

    final book = out['book']?.toString().trim();
    if (book != null &&
        _torahBooks.contains(book) &&
        _parshaInText.hasMatch(userMessage)) {
      if (out['parsha'] == null || out['parsha'].toString().isEmpty) {
        out['parsha'] = book;
      }
      if (_isParshaPhrase(userMessage) ||
          (topic != null && _isParshaPhrase(topic))) {
        out['book'] = null;
      }
    }

    return out;
  }

  static Map<String, dynamic> _normalizeDafYomi(
    Map<String, dynamic> json,
    String userMessage,
  ) {
    final out = Map<String, dynamic>.from(json);
    final combined = [
      userMessage,
      out['topic']?.toString() ?? '',
      out['daf_yomi']?.toString() ?? '',
    ].join(' ');

    if (!_dafYomiInText.hasMatch(combined)) return out;

    final topic = out['topic']?.toString().trim();
    if (topic != null && topic.isNotEmpty && _isDafYomiPhrase(topic)) {
      out['daf_yomi'] = _extractDafYomiValue(topic) ?? 'היום';
      out['topic'] = null;
    }

    final daf = out['daf_yomi']?.toString().trim();
    if (daf != null && daf.isNotEmpty) {
      out['daf_yomi'] = _extractDafYomiValue(daf) ?? 'היום';
    } else {
      out['daf_yomi'] = _extractDafYomiValue(userMessage) ?? 'היום';
    }

    return out;
  }

  static bool _isParshaPhrase(String text) {
    final t = text.trim();
    return t.contains('פרשת') ||
        t.contains('פרשה') ||
        t.contains('פרשיות') ||
        RegExp(r'parashat|parsha', caseSensitive: false).hasMatch(t);
  }

  static bool _isDafYomiPhrase(String text) {
    final t = text.trim();
    return _dafYomiInText.hasMatch(t);
  }

  static String? _extractParshaName(String text) {
    var t = text.trim();
    t = t.replaceAll(_stripParshaPrefix, '').trim();
    if (t.isEmpty ||
        t == 'השבוע' ||
        t.contains('השבוע') ||
        t.toLowerCase() == 'hashavua') {
      return 'השבוע';
    }
    return t;
  }

  /// "דף יומי" alone → היום; "דף יומי בבא מציעא" → בבא מציעא (hint, may still resolve via API).
  static String? _extractDafYomiValue(String text) {
    var t = text.trim();
    t = t.replaceAll(_stripDafPrefix, '').trim();
    if (t.isEmpty ||
        t == 'היום' ||
        t.contains('היום') ||
        t.toLowerCase() == 'today') {
      return 'היום';
    }
    return t;
  }
}
