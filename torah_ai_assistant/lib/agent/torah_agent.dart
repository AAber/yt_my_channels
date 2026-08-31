import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'intent_normalizer.dart';
import 'models.dart';
import '../llm/agent_config.dart';
import '../llm/groq_client.dart';
import '../sources/data_source.dart';
import '../sources/sefaria_calendar.dart';

class TorahAgent {
  final AgentConfig config;
  final List<DataSource> sources;
  final List<ChatMessage> _messages = [];
  late final GroqClient _groqClient;
  
  TorahAgent({
    required this.config,
    required this.sources,
  }) {
    _groqClient = GroqClient(apiKey: config.groqApiKey, model: config.model);
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getString('torah_chat_messages');
      
      if (messagesJson != null) {
        final messagesList = jsonDecode(messagesJson) as List;
        final loadedMessages = messagesList
            .map((json) => ChatMessage.fromJson(json))
            .toList();
        
        final now = DateTime.now();
        final hasRecentMessages = loadedMessages.any((msg) => 
          now.difference(msg.timestamp).inHours < 24
        );
        
        if (hasRecentMessages && loadedMessages.isNotEmpty) {
          _messages.clear();
          _messages.addAll(loadedMessages);
          return;
        }
      }
    } catch (e) {
      print('Error loading session: $e');
    }
    
    _addWelcomeMessage();
  }

  Future<void> saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = _messages.map((msg) => msg.toJson()).toList();
      await prefs.setString('torah_chat_messages', jsonEncode(messagesJson));
    } catch (e) {
      print('Error saving session: $e');
    }
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text:
          'שלום וברכה! 🌟 אני כאן כדי לעזור לכם למצוא שיעורים מכל המקורות שלנו.\n\n'
          'אתם יכול לשאול אותי דברים כמו:\n'
          '• מצא לי שיעור על שבת\n'
          '• הרב קלנר מבני דוד\n'
          '• הרב אזרד ממעלות\n'
          '• פרשת השבוע מחולון\n\n'
          '💡 עצה: ציינו שם רב כדי לקבל תוצאות מדויקות יותר!\n'
          'מה נלמד היום?',
      isUser: false,      timestamp: DateTime.now(),
    ));
  }

  Future<void> sendMessage(String userMessage) async {
    print('📱 User message: $userMessage');
    
    // Add user message
    _messages.add(ChatMessage(
      text: userMessage,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    try {
      print('🔍 Starting intent parsing...');
      
      // Parse intent using Groq
      final rawIntent = await _groqClient.parseIntent(userMessage);
      var intentJson = IntentNormalizer.normalize(rawIntent, userMessage);

      SefariaCalendarSnapshot? calendarSnapshot;
      if (SefariaCalendar.needsCalendarFetch(intentJson, userMessage)) {
        calendarSnapshot =
            await SefariaCalendar.fetchSnapshot(diaspora: false, logOutput: true);
        intentJson = Map<String, dynamic>.from(intentJson);

        if (SefariaCalendar.needsWeeklyResolution(intentJson, userMessage)) {
          final parsha = calendarSnapshot?.weeklyParsha;
          if (parsha != null && parsha.isResolved) {
            intentJson['parsha'] = parsha.hebrewName;
            print('📅 Resolved פרשת השבוע → ${parsha.hebrewName}');
          }
        }

        if (SefariaCalendar.needsDafYomiResolution(intentJson, userMessage)) {
          final daf = calendarSnapshot?.dafYomi;
          if (daf != null && daf.isResolved) {
            intentJson['daf_yomi'] = daf.hebrewDisplay;
            intentJson['daf_yomi_ref'] = daf.ref;
            print('📅 Resolved דף יומי → ${daf.hebrewDisplay} (${daf.ref})');
          }
        }
      }

      final intent = IntentResult.fromJson(intentJson);
      final calendarContext = calendarSnapshot?.toContextBlock();

      print('🔍 Intent parsed: ${intent.toJson()}');
      if (calendarContext != null && calendarContext.isNotEmpty) {
        print('📅 Sefaria calendar context:\n$calendarContext');
      }
      print('🔍 Searching ${sources.length} sources...');
      
      // Search all sources in parallel
      final searchFutures = sources.map((source) => source.search(intent));
      final allResultsLists = await Future.wait(searchFutures);
      
      // Flatten and merge results
      final allResults = <SourceResult>[];
      for (int i = 0; i < allResultsLists.length; i++) {
        final resultsList = allResultsLists[i];
        print('🔍 Source ${sources[i].name} returned ${resultsList.length} results');
        allResults.addAll(resultsList);
      }
      
      print('🔍 Total results before sorting: ${allResults.length}');

      // Keep only video results (mp4/vimeo for meir_api & david_api, always for youtube)
      final videoResults = allResults.where(_hasVideo).toList();
      print('🔍 Video-only results: ${videoResults.length}');

      // Sort by score and take top results
      videoResults.sort((a, b) => b.score.compareTo(a.score));
      final topResults = videoResults.take(intent.limit).toList();
      
      print('🔍 Top ${topResults.length} results selected');
      for (final result in topResults) {
        print('🔍 - ${result.title} (${result.source}) score: ${result.score}');
      }
      
      print('💬 Generating AI response...');
      
      // Generate warm response using Groq
      final (responseText, _) = await _groqClient.generateResponse(
        userMessage,
        topResults.map((r) => r.toJson()).toList(),
        calendarContext: calendarContext,
      );
      
      print('💬 Final response: $responseText');
      print('💬 Response length: ${responseText.length} chars');
      print('💬 Response bytes: ${utf8.encode(responseText).length} bytes');
      
      // Validate Hebrew content
      String finalResponse = responseText;
      if (!_containsValidHebrew(responseText) && topResults.isNotEmpty) {
        print('💬 WARNING: Response may have encoding issues, using fallback');
        finalResponse = _createFallbackResponse(
          topResults,
          userMessage,
          calendarContext: calendarContext,
        );
      }
      
      // Add AI response
      _messages.add(ChatMessage(
        text: finalResponse,
        isUser: false,
        timestamp: DateTime.now(),
        searchResults: topResults,
      ));
      
      await saveSession();
      print('💾 Session saved successfully');
      
    } on GroqRateLimitException catch (e) {
      debugPrint('❌ Rate limit: retry at ${e.retryTimeFormatted}');
      _messages.add(ChatMessage(
        text: 'הגענו למגבלת השימוש היומית של ה-AI. ⏳\n\nהסיבה: מגבלת טוקנים יומית של Groq הוגעה.\nניתן לנסות שוב בשעה ${e.retryTimeFormatted}.',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } catch (e, stackTrace) {
      debugPrint('❌ Error in sendMessage: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      
      _messages.add(ChatMessage(
        text: 'מצטער, יש לי בעיה טכנית כרגע. אנא נסה שוב בעוד רגע 🤖\n\nאם הבעיה נמשכת, בדוק את החיבור לאינטרנט או נסה שאלה אחרת.',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    }
  }

  void clearChat() {
    _messages.clear();
    _addWelcomeMessage();
    saveSession();
  }

  Future<void> dispose() async {
    // Close API connections if needed
    // API adapters don't need explicit cleanup like database adapters
  }

  /// Returns true if the result has video content (not audio-only).
  bool _hasVideo(SourceResult r) {
    if (r.source == 'youtube') return true;
    final m = r.metadata;
    // meir_api uses vimeo_path / mp4_path
    if (r.source == 'meir_api') {
      return (m['vimeo_path']?.toString().isNotEmpty ?? false) ||
             (m['mp4_path']?.toString().isNotEmpty ?? false);
    }
    // david_api uses mp4_url
    if (r.source == 'david_api') {
      return m['mp4_url']?.toString().isNotEmpty ?? false;
    }
    return false;
  }

  bool _containsValidHebrew(String text) {
    // Check if text contains Hebrew characters (Unicode range 0x0590-0x05FF)
    final hebrewRegex = RegExp(r'[֐-׿]');
    return hebrewRegex.hasMatch(text);
  }

  String _createFallbackResponse(
    List<SourceResult> results,
    String userMessage, {
    String? calendarContext,
  }) {
    if (results.isEmpty) {
      if (calendarContext != null && calendarContext.isNotEmpty) {
        return 'לפי ספריא:\n$calendarContext\n\nלא מצאתי שיעורים מתאימים במאגרים שלנו כרגע — נסה לחפש לפי שם הפרשה, מסכת, או רב מסוים.';
      }
      return 'מצטער, לא מצאתי שיעורים על הנושא שביקשת. נסה לחפש משהו אחר או לנסח את השאלה באופן אחר.';
    }

    final topResult = results.first;
    final teacher = topResult.teacher ?? 'ללא שם רב';
    final source = topResult.source == 'meir_api' ? 'מכון מאיר' : 
                   topResult.source == 'david_api' ? 'ישיבת בני דוד בעלי' : 
                   topResult.source == 'youtube' ? 'יוטיוב' : 'ספריא';
    
    String response = 'מצאתי עבורך ${results.length} שיעורים על הנושא. ';
    
    if (results.length == 1) {
      response = 'מצאתי עבורך שיעור מעניין: "${topResult.title}" של $teacher מ$source. ';
    } else {
      response += 'השיעור הראשון הוא "${topResult.title}" של $teacher. ';
    }
    
    response += 'האם תרצה שאחפש משהו מדוייק יותר?';
    
    return response;
  }
}