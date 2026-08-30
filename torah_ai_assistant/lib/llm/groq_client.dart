import 'dart:convert';
import 'package:http/http.dart' as http;
import 'agent_config.dart';

const bool _kDebugGroq = true;

void _log(String tag, String message) {
  if (_kDebugGroq) {
    // ignore: avoid_print
    print('[$tag] $message');
  }
}

// ---------------------------------------------------------------------------
// JSON / think-block helpers
// ---------------------------------------------------------------------------

(String, String?) _stripThinkBlocks(String raw) {
  var text = raw;
  String? think;
  for (final tag in ['think', 'redacted_thinking']) {
    final closed = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(text);
    if (closed != null) {
      think ??= closed.group(1)?.trim();
      text = text.replaceAll(RegExp('<$tag>.*?</$tag>', dotAll: true), '');
      continue;
    }
    final unclosed = RegExp('<${tag}>(.*?)\$', dotAll: true).firstMatch(text);
    if (unclosed != null) {
      think ??= unclosed.group(1)?.trim();
      text = text.replaceAll(RegExp('<${tag}>.*\$', dotAll: true), '');
    }
  }
  return (text.trim(), think?.isEmpty == true ? null : think);
}

String _stripFences(String raw) =>
    raw.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '').replaceAll('```', '').trim();

String? _extractFirstJsonObject(String text) {
  int depth = 0;
  int? start;
  for (int i = 0; i < text.length; i++) {
    if (text[i] == '{') {
      depth++;
      start ??= i;
    } else if (text[i] == '}') {
      depth--;
      if (depth == 0 && start != null) return text.substring(start, i + 1);
    }
  }
  return null;
}

Map<String, dynamic>? _tryParseJson(String raw) {
  try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) {}
  final stripped = _stripFences(raw);
  try { return jsonDecode(stripped) as Map<String, dynamic>; } catch (_) {}
  final extracted = _extractFirstJsonObject(stripped);
  if (extracted != null) {
    try { return jsonDecode(extracted) as Map<String, dynamic>; } catch (_) {}
  }
  return null;
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

class GroqRateLimitException implements Exception {
  final String retryAfter;
  final DateTime retryAt;

  GroqRateLimitException({required this.retryAfter})
      : retryAt = DateTime.now().add(_parseDuration(retryAfter));

  static Duration _parseDuration(String s) {
    int hours = 0, minutes = 0;
    double seconds = 0;
    final h = RegExp(r'(\d+)h').firstMatch(s);
    final m = RegExp(r'(\d+)m').firstMatch(s);
    final sec = RegExp(r'([\d.]+)s').firstMatch(s);
    if (h != null) hours = int.parse(h.group(1)!);
    if (m != null) minutes = int.parse(m.group(1)!);
    if (sec != null) seconds = double.parse(sec.group(1)!);
    return Duration(hours: hours, minutes: minutes, milliseconds: (seconds * 1000).round());
  }

  String get retryTimeFormatted {
    final h = retryAt.hour.toString().padLeft(2, '0');
    final m = retryAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ModelUnavailableException implements Exception {
  final String message;
  _ModelUnavailableException(this.message);
}

// ---------------------------------------------------------------------------
// GroqClient
// ---------------------------------------------------------------------------

class GroqClient implements LlmProvider {
  final String apiKey;
  final Duration timeout;
  final String _baseUrl = 'https://api.groq.com/openai/v1';

  static const List<String> _staticFallbacks = [
    'qwen/qwen3-32b',
    'qwen/qwen3.6-27b',
    'openai/gpt-oss-20b',
  ];

  final String preferredModel;
  List<String>? _liveModels;

  GroqClient({
    required this.apiKey,
    String? model,
    this.timeout = const Duration(seconds: 30),
  }) : preferredModel = _normalizePreferredModel(model);

  static String _normalizePreferredModel(String? model) {
    if (model == null || model.isEmpty || _isDeprecatedModel(model)) {
      return _staticFallbacks.first;
    }
    return model;
  }

  static bool _isDeprecatedModel(String model) =>
      model.contains('llama') || model.contains('mixtral');

  static bool _supportsStrictJsonMode(String model) =>
      model.contains('gpt-oss');

  String get _effectivePreferredModel =>
      _isDeprecatedModel(preferredModel) ? _staticFallbacks.first : preferredModel;

  Future<List<String>> _getCandidates() async {
    if (_liveModels != null) return _liveModels!;
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/models'),
              headers: {'Authorization': 'Bearer $apiKey'})
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final ids = (data['data'] as List)
            .map((m) => m['id'] as String)
            .where((id) =>
                id.contains('qwen') ||
                (id.contains('openai/gpt-oss') && !id.contains('safeguard')))
            .toList()
          ..sort((a, b) => b.compareTo(a));
        _log('Groq', 'Live models: $ids');
        _liveModels = ids;
        return ids;
      }
    } catch (e) {
      _log('Groq', 'Could not fetch /models, using static fallbacks: $e');
    }
    return _staticFallbacks;
  }

  @override
  Future<String> call(List<Map<String, String>> messages) async {
    final (content, _) = await callWithThink(messages);
    return content;
  }

  Future<(String, String?)> callWithThink(List<Map<String, String>> messages) async {
    final allModels = await _getCandidates();
    final candidates = [
      _effectivePreferredModel,
      ...allModels.where((m) => m != _effectivePreferredModel && !_isDeprecatedModel(m)),
    ];

    Object? lastError;
    for (final candidate in candidates) {
      _log('Groq', 'Request: ${messages.length} messages, model=$candidate');
      try {
        return await _callModel(candidate, messages);
      } on _ModelUnavailableException catch (e) {
        _log('Groq', 'Model $candidate unavailable: $e — trying next');
        _liveModels?.remove(candidate);
        lastError = e;
      } on GroqRateLimitException {
        rethrow;
      } catch (e) {
        _log('Groq', 'Model $candidate failed: $e — trying next');
        lastError = e;
      }
    }
    _log('Groq', 'All models failed. Last error: $lastError');
    return ('Sorry, all models are currently unavailable. Please try again later 🤖', null);
  }

  Future<(String, String?)> _callModel(
      String modelName, List<Map<String, String>> messages) async {
    final isIntentCall = messages.any((m) =>
        m['role'] == 'system' &&
        (m['content'] ?? '').contains('channel finder'));
    final jsonMode = isIntentCall && _supportsStrictJsonMode(modelName);

    final requestBody = <String, dynamic>{
      'model': modelName,
      'messages': messages,
      'temperature': isIntentCall ? 0.2 : 0.7,
      'max_tokens': isIntentCall ? 512 : 2000,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    };

    final response = await http
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

    _log('Groq', 'Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final String body = (() {
        try { return utf8.decode(response.bodyBytes); }
        catch (e) { return response.body; }
      })();
      _log('Groq', 'Raw body: $body');
      final data = jsonDecode(body) as Map<String, dynamic>;
      final raw = data['choices'][0]['message']['content'] as String;
      final (content, think) = _stripThinkBlocks(raw);
      _log('Groq', 'Content: $content');
      return (content, think);
    }

    final errorBody = utf8.decode(response.bodyBytes);
    _log('Groq', 'Error ${response.statusCode}: $errorBody');

    if (response.statusCode == 429) {
      String retryAfter = '15m';
      try {
        final body = jsonDecode(errorBody) as Map<String, dynamic>;
        final msg = body['error']?['message']?.toString() ?? '';
        final m = RegExp(r'try again in ([\dhms.]+)').firstMatch(msg);
        if (m != null) retryAfter = m.group(1)!;
      } catch (_) {}
      throw GroqRateLimitException(retryAfter: retryAfter);
    }

    if (response.statusCode == 404 ||
        (response.statusCode == 400 &&
            errorBody.contains('model') &&
            (errorBody.contains('decommissioned') ||
                errorBody.contains('deprecated') ||
                errorBody.contains('not found') ||
                errorBody.contains('does not exist')))) {
      throw _ModelUnavailableException(errorBody);
    }

    throw Exception('Groq API error: ${response.statusCode} — $errorBody');
  }

  // -------------------------------------------------------------------------
  // Intent parsing (used by TorahAgent)
  // -------------------------------------------------------------------------

  static Map<String, dynamic> _defaultIntent() => {
    'topic': null, 'teacher': null, 'source': null, 'channel': null,
    'book': null, 'parsha': null, 'daf_yomi': null, 'duration_max': null, 'limit': 5,
  };

  Future<Map<String, dynamic>> parseIntent(String userMessage) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _intentSystemPrompt},
      {'role': 'user', 'content': userMessage},
    ];
    try {
      final raw = await call(messages);
      final parsed = _tryParseJson(raw);
      if (parsed != null) return {..._defaultIntent(), ...parsed};
    } catch (e) {
      _log('Intent', 'failed: $e');
    }
    return _defaultIntent();
  }

  Future<(String, String?)> generateResponse(
    String userMessage,
    List<Map<String, dynamic>> searchResults, {
    String? calendarContext,
  }) async {
    final resultsText = searchResults.map((r) {
      final sourceId = r['source']?.toString() ?? '';
      final channelTitle = r['metadata']?['channel_title']?.toString();
      const names = {'david_api': 'ישיבת בני דוד בעלי', 'meir_api': 'מכון מאיר', 'youtube': 'יוטיוב'};
      final sourceName = channelTitle ?? names[sourceId] ?? sourceId;
      return '- ${r['title']} ($sourceName) - ${r['snippet']}';
    }).join('\n');
    final calendarBlock = (calendarContext?.isNotEmpty == true)
        ? '\n\nלוח לימוד מספריא:\n$calendarContext' : '';
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _responseSystemPrompt},
      {'role': 'user', 'content': 'User asked: "$userMessage"$calendarBlock\n\nSearch results:\n$resultsText'},
    ];
    return callWithThink(messages);
  }

  static const _intentSystemPrompt = '''/no_think
You are a search intent parser for a Torah learning app.
Extract the user's search intent and return ONLY valid JSON — no markdown, no code blocks, no other text.
Fields: topic, teacher, source, channel, book, parsha, daf_yomi, duration_max, limit.
Return ONLY the JSON object.''';

  static const _responseSystemPrompt = '''/no_think
You are a warm Torah learning assistant. Respond in Hebrew in 2-4 sentences.
Mention top results by title and teacher. Never invent sources.''';

  // -------------------------------------------------------------------------
  // Channel finder — asks 3 questions and returns 3 channel suggestions
  // -------------------------------------------------------------------------

  /// Given the conversation so far (question/answer pairs), returns the next
  /// question or, after 3 answers, a JSON list of 3 channel suggestions.
  Future<ChannelFinderResponse> channelFinderStep(
      List<Map<String, String>> conversation) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _channelFinderSystemPrompt},
      ...conversation,
    ];

    final String raw;
    try {
      raw = await call(messages);
    } catch (e) {
      _log('ChannelFinder', 'call() threw: $e');
      return ChannelFinderResponse.question('Sorry, something went wrong. Please try again.');
    }

    _log('ChannelFinder', 'Raw: $raw');

    // Try to parse as JSON suggestions first
    final parsed = _tryParseJson(raw);
    if (parsed != null && parsed.containsKey('suggestions')) {
      final list = parsed['suggestions'] as List;
      final suggestions = list.map((s) => ChannelSuggestion(
        channelId: s['channel_id'] as String,
        title: s['title'] as String,
        reason: s['reason'] as String,
      )).toList();
      return ChannelFinderResponse.suggestions(suggestions);
    }

    return ChannelFinderResponse.question(raw.trim());
  }

  static const _channelFinderSystemPrompt = '''/no_think
You are a friendly YouTube channel recommendation assistant.
Your job: ask the user exactly 3 short questions to understand their music/content taste,
then suggest exactly 3 YouTube channels.

Rules:
- Ask ONE question at a time. Keep questions short and friendly.
- After the user has answered 3 questions, respond with ONLY valid JSON — no other text:
  {"suggestions": [
    {"channel_id": "UC...", "title": "Channel Name", "reason": "one sentence why"},
    {"channel_id": "UC...", "title": "Channel Name", "reason": "one sentence why"},
    {"channel_id": "UC...", "title": "Channel Name", "reason": "one sentence why"}
  ]}
- Use real YouTube channel IDs (UC... format, 24 chars).
- Base suggestions on the user's answers. Be specific and helpful.
- Do NOT suggest channels you are not confident exist on YouTube.
- Questions should cover: genre/style, mood/vibe, and a specific preference (artist, language, era, etc.).
- Respond in the same language the user uses.''';
}

// ---------------------------------------------------------------------------
// Channel finder response types
// ---------------------------------------------------------------------------

enum ChannelFinderResponseType { question, suggestions }

class ChannelFinderResponse {
  final ChannelFinderResponseType type;
  final String? question;
  final List<ChannelSuggestion>? suggestions;

  ChannelFinderResponse.question(this.question)
      : type = ChannelFinderResponseType.question,
        suggestions = null;

  ChannelFinderResponse.suggestions(this.suggestions)
      : type = ChannelFinderResponseType.suggestions,
        question = null;
}

class ChannelSuggestion {
  final String channelId;
  final String title;
  final String reason;

  const ChannelSuggestion({
    required this.channelId,
    required this.title,
    required this.reason,
  });
}
