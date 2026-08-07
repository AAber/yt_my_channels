import 'dart:convert';
import 'package:http/http.dart' as http;
import 'agent_config.dart';

/// Toggles verbose debug logging. Set to false for production builds.
const bool _kDebugGroq = true;

void _log(String tag, String message) {
  if (_kDebugGroq) {
    // ignore: avoid_print
    print('[$tag] $message');
  }
}

// ---------------------------------------------------------------------------
// Intent field keys — single source of truth to avoid typo bugs.
// ---------------------------------------------------------------------------
class _K {
  static const topic       = 'topic';
  static const teacher     = 'teacher';
  static const source      = 'source';
  static const channel     = 'channel';
  static const book        = 'book';
  static const parsha      = 'parsha';
  static const dafYomi     = 'daf_yomi';
  static const durationMax = 'duration_max';
  static const limit       = 'limit';
}

// ---------------------------------------------------------------------------
// Safe default when intent parsing completely fails.
// ---------------------------------------------------------------------------
Map<String, dynamic> _defaultIntent() => {
  _K.topic:       null,
  _K.teacher:     null,
  _K.source:      null,
  _K.channel:     null,
  _K.book:        null,
  _K.parsha:      null,
  _K.dafYomi:     null,
  _K.durationMax: null,
  _K.limit:       5,
};

// ---------------------------------------------------------------------------
// JSON extraction helpers — handles nested braces correctly.
// ---------------------------------------------------------------------------

/// Strips ``` fences that some models add despite being told not to.
String _stripFences(String raw) {
  final fencePattern = RegExp(r'```[a-zA-Z]*\n?');
  return raw
      .replaceAll(fencePattern, '')
      .replaceAll('```', '')
      .trim();
}

/// Extracts the first balanced JSON object from [text].
/// Handles nested objects correctly, unlike a naive `[^}]*` regex.
String? _extractFirstJsonObject(String text) {
  int depth = 0;
  int? start;
  for (int i = 0; i < text.length; i++) {
    if (text[i] == '{') {
      depth++;
      start ??= i;
    } else if (text[i] == '}') {
      depth--;
      if (depth == 0 && start != null) {
        return text.substring(start, i + 1);
      }
    }
  }
  return null;
}

/// Tries to decode JSON from [raw], applying fence-stripping and balanced
/// brace extraction as fallbacks. Returns null if all attempts fail.
Map<String, dynamic>? _tryParseJson(String raw) {
  // Attempt 1 — parse as-is.
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {}

  // Attempt 2 — strip markdown fences, then parse.
  final stripped = _stripFences(raw);
  try {
    return jsonDecode(stripped) as Map<String, dynamic>;
  } catch (_) {}

  // Attempt 3 — extract the first balanced `{...}` block.
  final extracted = _extractFirstJsonObject(stripped);
  if (extracted != null) {
    try {
      return jsonDecode(extracted) as Map<String, dynamic>;
    } catch (_) {}
  }

  return null;
}

// ---------------------------------------------------------------------------
// Typed exception for Groq rate limit errors.
// ---------------------------------------------------------------------------
class GroqRateLimitException implements Exception {
  /// Human-readable retry delay, e.g. "16m48.288s"
  final String retryAfter;
  /// The exact DateTime when the user can retry.
  final DateTime retryAt;

  GroqRateLimitException({required this.retryAfter})
      : retryAt = DateTime.now().add(_parseDuration(retryAfter));

  /// Parses strings like "16m48.288s", "5s", "1h2m3s".
  static Duration _parseDuration(String s) {
    int hours = 0, minutes = 0;
    double seconds = 0;
    final h = RegExp(r'(\d+)h').firstMatch(s);
    final m = RegExp(r'(\d+)m').firstMatch(s);
    final sec = RegExp(r'([\d.]+)s').firstMatch(s);
    if (h != null) hours = int.parse(h.group(1)!);
    if (m != null) minutes = int.parse(m.group(1)!);
    if (sec != null) seconds = double.parse(sec.group(1)!);
    return Duration(
      hours: hours,
      minutes: minutes,
      milliseconds: (seconds * 1000).round(),
    );
  }

  /// Formats [retryAt] as HH:MM in Hebrew context.
  String get retryTimeFormatted {
    final t = retryAt;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ---------------------------------------------------------------------------
// GroqClient
// ---------------------------------------------------------------------------

class GroqClient implements LlmProvider {
  final String apiKey;
  final String model;
  final Duration timeout;
  final String _baseUrl = 'https://api.groq.com/openai/v1';

  GroqClient({
    required this.apiKey,
    this.model = 'llama-3.3-70b-versatile',
    this.timeout = const Duration(seconds: 30),
  });

  // -------------------------------------------------------------------------
  // Core HTTP call
  // -------------------------------------------------------------------------

  @override
  Future<String> call(List<Map<String, String>> messages) async {
    _log('Groq', 'Request: ${messages.length} messages');

    final requestBody = {
      'model': model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 1000,
    };

    _log('Groq', 'Body: ${jsonEncode(requestBody)}');

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: utf8.encode(jsonEncode(requestBody)),
          )
          .timeout(timeout);
    } catch (e) {
      _log('Groq', 'Network/timeout error: $e');
      return 'מצטער, יש לי בעיה טכנית. נסה שוב בעוד רגע 🤖';
    }

    _log('Groq', 'Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final String body;
      try {
        body = utf8.decode(response.bodyBytes);
      } catch (e) {
        _log('Groq', 'UTF-8 decode failed, falling back: $e');
        return response.body;
      }

      _log('Groq', 'Raw body: $body');

      final data    = jsonDecode(body) as Map<String, dynamic>;
      final content = data['choices'][0]['message']['content'] as String;

      _log('Groq', 'Content: $content');

      if (!_containsValidHebrew(content)) {
        _log('Groq', 'WARNING: response may have Hebrew encoding issues');
      }

      return content;
    } else {
      final errorBody = utf8.decode(response.bodyBytes);
      _log('Groq', 'Error ${response.statusCode}: $errorBody');

      if (response.statusCode == 429) {
        // Parse "Please try again in 16m48.288s" from the error message.
        String retryAfter = '15m';
        try {
          final body = jsonDecode(errorBody) as Map<String, dynamic>;
          final msg = body['error']?['message']?.toString() ?? '';
          final m = RegExp(r'try again in ([\dhms.]+)').firstMatch(msg);
          if (m != null) retryAfter = m.group(1)!;
        } catch (_) {}
        throw GroqRateLimitException(retryAfter: retryAfter);
      }

      throw Exception('Groq API error: ${response.statusCode} — $errorBody');
    }
  }

  // -------------------------------------------------------------------------
  // Intent parsing
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> parseIntent(String userMessage) async {
    _log('Intent', 'Parsing: $userMessage');

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _intentSystemPrompt},
      {'role': 'user',   'content': userMessage},
    ];

    final String raw;
    try {
      raw = await call(messages);
    } catch (e) {
      _log('Intent', 'call() threw: $e — using default intent');
      return _defaultIntent();
    }

    _log('Intent', 'Raw response: $raw');

    final parsed = _tryParseJson(raw);
    if (parsed != null) {
      // Ensure required fields are present (merge with defaults for safety).
      final result = {..._defaultIntent(), ...parsed};
      _log('Intent', 'Parsed: $result');
      return result;
    }

    _log('Intent', 'All JSON parse attempts failed — using default intent');
    return _defaultIntent();
  }

  // -------------------------------------------------------------------------
  // Response generation
  // -------------------------------------------------------------------------

  static const _sourceDisplayNames = {
    'david_api': 'ישיבת בני דוד בעלי',
    'meir_api':  'מכון מאיר',
    'youtube':   'יוטיוב',
    'sefaria':   'ספריא',
  };

  Future<String> generateResponse(
    String userMessage,
    List<Map<String, dynamic>> searchResults, {
    String? calendarContext,
  }) async {
    _log('Response', 'Generating for: $userMessage');
    _log('Response', 'Results count: ${searchResults.length}');

    final resultsText = searchResults.map((r) {
      final sourceId = r['source']?.toString() ?? '';
      final channelTitle = r['metadata']?['channel_title']?.toString();
      final sourceName = channelTitle ?? _sourceDisplayNames[sourceId] ?? sourceId;
      return '- ${r['title']} ($sourceName) - ${r['snippet']}';
    }).join('\n');

    final userContent = _buildUserContent(
      userMessage: userMessage,
      resultsText: resultsText,
      calendarContext: calendarContext,
    );

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _responseSystemPrompt},
      {'role': 'user',   'content': userContent},
    ];

    final response = await call(messages);
    _log('Response', 'Generated: $response');
    return response;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  static String _buildUserContent({
    required String userMessage,
    required String resultsText,
    String? calendarContext,
  }) {
    final calendarBlock = (calendarContext != null && calendarContext.isNotEmpty)
        ? '\n\nלוח לימוד מספריא (חובה להשתמש בשאלות על פרשת השבוע / דף יומי — אל תנחש):\n$calendarContext'
        : '';

    return 'User asked: "$userMessage"$calendarBlock\n\nSearch results:\n$resultsText';
  }

  /// Checks for Hebrew characters across the full Hebrew Unicode block
  /// (U+0590–U+05FF), covering cantillation, vowels, and letters.
  static bool _containsValidHebrew(String text) {
    return text.runes.any((r) => r >= 0x0590 && r <= 0x05FF);
  }

  // -------------------------------------------------------------------------
  // System prompts (kept as static constants to keep methods readable)
  // -------------------------------------------------------------------------

  static const _intentSystemPrompt = '''You are a search intent parser for a Torah learning app.
Extract the user's search intent and return ONLY valid JSON — no markdown, no code blocks, no other text.

IMPORTANT: Return ONLY the JSON object, nothing else. No \`\`\`json\`\`\` blocks, no explanations.

The app has 8 content sources:
1. ישיבת בני דוד בעלי (david_api)
   Users may say: "בני דוד", "ישיבת בני דוד", "בני דוד בעלי", "bneidavid".
   Known rabbis: קלנר, קשתיאל, אוהד, אלי, טורנר, יגאל, לונדין, פרטוש.
2. עוד יוסף חי — youtube channel UCQfTTiNEkZ3_HYr9S4zQB0g
   Users may say: "עוד יוסף חי", "יוסף", "יוסף חי".
   Known rabbis: שפירא, דוד בנימין.
3. חב"ד רמת אביב — youtube channel UCJYMW0GZaanXsFnt5pnI6QA
   Users may say: "חב"ד רמת אביב", "חב"ד", "חבד", "אביב".
   Known rabbis: גינזבורג, שנאורסון, גולדברג.
4. ישיבת הסדר מעלות — youtube channel UCXGUXEMhk3PaZxep7NVTM5A
   Users may say: "מעלות", "הסדר מעלות", "ישיבת מעלות".
   Known rabbis: אזרד, ויצמן, שטרן, אהרנסון.
5. מעייני ישראל — youtube channel UCdoHZjm2ku452xK4f5gRzZw
   Users may say: "מעייני ישראל", "מעיינות", "מעייני".
   Known rabbis: קרישבסקי, ערלנגר, וואלבערג, גופין, זושא, הלוי, הורוביץ.
6. ישיבת חולון — youtube channel UCWdBoc1ZurwXJMOSq0eLx-A
   Users may say: "חולון", "ישיבת חולון".
   Known rabbis: שאוליאן, נהון, שלו.
7. ממעל ממש — youtube channel UCkrqrlLmV0OBP9a3jMWTAcw
   Users may say: "ממעל", "ממעל ממש".
8. ישיבת שדרות — youtube channel UC4jSWBYE-jIllmJmsZC5xRQ
   Users may say: "שדרות", "ישיבת שדרות".

IMPORTANT — teacher field:
- ALWAYS extract a rabbi/teacher name when one is mentioned, even partially.
- Strip the prefix "רב"/"הרב" — keep the family name only.
  Examples: "רב קלנר" → "קלנר"; "הרב אזרד" → "אזרד"; "הרב שאוליאן" → "שאוליאן"
- If no rabbi is named, set teacher to null.

Fields:
  topic         (string|null)  — general Torah subject: "תפילה", "שבת", "אמונה", "הלכה"
                                 Do NOT use topic for weekly Torah portions (see parsha).
  teacher       (string|null)  — rabbi family name only (strip "רב"/"הרב" prefix)
  source        (string|null)  — set ONLY when user explicitly names a source:
                                 "בני דוד" / "בני דוד בעלי" → "david_api"
                                 "יוטיוב" / "youtube" → "youtube"
                                 null when no source is mentioned (search all sources)
                                 COMPOUND: "רב קלנר מבני דוד" → teacher="קלנר", source="david_api"
                                 COMPOUND: "הרב אזרד ממעלות" → teacher="אזרד", source="youtube", channel="UCXGUXEMhk3PaZxep7NVTM5A"
  channel       (string|null)  — specific YouTube channel ID. Set when user names one of the 7 YouTube sources.
                                 Map EXACTLY as follows (no other values allowed):
                                 "עוד יוסף חי" / "יוסף"            → "UCQfTTiNEkZ3_HYr9S4zQB0g"
                                 "חב"ד" / "חב"ד רמת אביב" / "אביב" → "UCJYMW0GZaanXsFnt5pnI6QA"
                                 "מעלות" / "הסדר מעלות"             → "UCXGUXEMhk3PaZxep7NVTM5A"
                                 "מעייני" / "מעייני ישראל"          → "UCdoHZjm2ku452xK4f5gRzZw"
                                 "חולון" / "ישיבת חולון"            → "UCWdBoc1ZurwXJMOSq0eLx-A"
                                 "ממעל" / "ממעל ממש"                → "UCkrqrlLmV0OBP9a3jMWTAcw"
                                 "שדרות" / "ישיבת שדרות"            → "UC4jSWBYE-jIllmJmsZC5xRQ"
                                 When a known rabbi is mentioned without a source, infer the channel:
                                 אזרד/ויצמן/שטרן/אהרנסון        → "UCXGUXEMhk3PaZxep7NVTM5A"
                                 קרישבסקי/ערלנגר/וואלבערג/גופין → "UCdoHZjm2ku452xK4f5gRzZw"
                                 שאוליאן/נהון/שלו                → "UCWdBoc1ZurwXJMOSq0eLx-A"
                                 גינזבורג/שנאורסון/גולדברג       → "UCJYMW0GZaanXsFnt5pnI6QA"
                                 דוד בנימין                      → "UCQfTTiNEkZ3_HYr9S4zQB0g"
                                 null when no YouTube source is implied
  book          (string|null)  — full Chumash book or Talmud tractate (whole book, not parsha)
  parsha        (string|null)  — weekly Torah portion. "פרשת נח" → "נח"; "פרשת השבוע" → "השבוע"
  daf_yomi      (string|null)  — daf yomi. "דף יומי" alone → "היום"
  duration_max  (int|null)     — max lesson length in minutes
  limit         (int)          — number of results, default 5

Examples:
{"topic":"תפילה","teacher":"פיירמן","source":null,"channel":null,"book":null,"parsha":null,"daf_yomi":null,"duration_max":null,"limit":5}
{"topic":null,"teacher":"קלנר","source":"david_api","channel":null,"book":null,"parsha":null,"daf_yomi":null,"duration_max":null,"limit":5}
{"topic":null,"teacher":"אזרד","source":"youtube","channel":"UCXGUXEMhk3PaZxep7NVTM5A","book":null,"parsha":null,"daf_yomi":null,"duration_max":null,"limit":5}
{"topic":null,"teacher":"שאוליאן","source":"youtube","channel":"UCWdBoc1ZurwXJMOSq0eLx-A","book":null,"parsha":null,"daf_yomi":null,"duration_max":null,"limit":5}
{"topic":null,"teacher":"קרישבסקי","source":"youtube","channel":"UCdoHZjm2ku452xK4f5gRzZw","book":null,"parsha":null,"daf_yomi":null,"duration_max":null,"limit":5}
{"topic":null,"teacher":null,"source":"youtube","channel":"UCkrqrlLmV0OBP9a3jMWTAcw","book":null,"parsha":"השבוע","daf_yomi":null,"duration_max":null,"limit":5}
{"topic":null,"teacher":null,"source":null,"channel":null,"book":null,"parsha":"נח","daf_yomi":null,"duration_max":null,"limit":5}
{"topic":null,"teacher":null,"source":null,"channel":null,"book":null,"parsha":"השבוע","daf_yomi":null,"duration_max":null,"limit":5}
{"topic":null,"teacher":null,"source":null,"channel":null,"book":null,"parsha":null,"daf_yomi":"היום","duration_max":null,"limit":5}''';

  static const _responseSystemPrompt = '''You are a warm, knowledgeable Torah learning assistant — like a helpful
study partner who knows the library well.

IMPORTANT INSTRUCTIONS:
- ALWAYS respond in proper Hebrew text using Hebrew Unicode characters
- Respond in Hebrew in 2–4 sentences
- Use UTF-8 encoding for all Hebrew text
- Never use garbled or corrupted characters

The app has 8 content sources — mention them by their correct Hebrew names:
- "david_api" → ישיבת בני דוד בעלי
- "youtube"   → יוטיוב — 7 channels: עוד יוסף חי, חב"ד רמת אביב, ישיבת הסדר מעלות, מעייני ישראל, ישיבת חולון, ממעל ממש, ישיבת שדרות

Content guidelines:
- Mention the top results by title and teacher
- Note if results come from different sources using the correct source names above
- When the user asked about a פרשה or פרשת השבוע, treat it as the weekly Torah portion
  from the Five Books of Moses (חומש), not a generic "topic"
- When the user asked about דף יומי, treat it as the daily Talmud page (מסכת + דף) from the
  daf yomi cycle — not a generic "topic"
- If "לוח לימוד מספריא" context is provided below, use those exact names and refs — do not guess
- Do NOT include YouTube URLs or links in your response text — results are shown as tappable buttons
- Offer to refine: filter by length, find related topics, or go deeper on one result
- Use simple, respectful language. Hebrew terms are fine where natural
- Never invent lessons or sources. Only refer to the results you were given
- Be encouraging and helpful, like a caring teacher

Example good response: "מצאתי עבורך שיעורים מעניינים על הנושא. יש כאן שיעור מישיבת בני דוד בעלי ועוד שיעורים מישיבת חולון. האם תרצה שאחפש משהו מדוייק יותר?"''';
}
