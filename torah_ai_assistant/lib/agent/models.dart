class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<SourceResult>? searchResults;
  final String? thinkText;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.searchResults,
    this.thinkText,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'searchResults': searchResults?.map((r) => r.toJson()).toList(),
    'thinkText': thinkText,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'],
    isUser: json['isUser'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    searchResults: json['searchResults']?.map<SourceResult>((r) => SourceResult.fromJson(r)).toList(),
    thinkText: json['thinkText'],
  );
}

class IntentResult {
  final String? topic;
  final String? teacher;
  final String? source; // "david_api" | "youtube" | "meir_api" | null=all
  final String? channel; // specific YouTube channel ID, e.g. "UCkrqrlLmV0OBP9a3jMWTAcw"
  final String? book;
  final String? parsha;
  final String? dafYomi;
  final int? durationMax;
  final int limit;

  IntentResult({
    this.topic,
    this.teacher,
    this.source,
    this.channel,
    this.book,
    this.parsha,
    this.dafYomi,
    this.durationMax,
    this.limit = 5,
  });

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'teacher': teacher,
    'source': source,
    'channel': channel,
    'book': book,
    'parsha': parsha,
    'daf_yomi': dafYomi,
    'duration_max': durationMax,
    'limit': limit,
  };

  factory IntentResult.fromJson(Map<String, dynamic> json) => IntentResult(
    topic: json['topic'],
    teacher: json['teacher'],
    source: json['source'],
    channel: json['channel'],
    book: json['book'],
    parsha: json['parsha'],
    dafYomi: json['daf_yomi'],
    durationMax: json['duration_max'],
    limit: json['limit'] ?? 5,
  );
}

class SourceResult {
  final String title;
  final String? teacher;
  final String source;
  final double score;
  final String snippet;
  final Map<String, dynamic> metadata;

  SourceResult({
    required this.title,
    this.teacher,
    required this.source,
    required this.score,
    required this.snippet,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'teacher': teacher,
    'source': source,
    'score': score,
    'snippet': snippet,
    'metadata': metadata,
  };

  factory SourceResult.fromJson(Map<String, dynamic> json) => SourceResult(
    title: json['title'],
    teacher: json['teacher'],
    source: json['source'],
    score: json['score']?.toDouble() ?? 0.0,
    snippet: json['snippet'] ?? '',
    metadata: json['metadata'] ?? {},
  );
}