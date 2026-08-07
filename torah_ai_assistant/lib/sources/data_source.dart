import '../agent/models.dart';

abstract class DataSource {
  String get name;
  Future<List<SourceResult>> search(IntentResult intent);
}

class WindexDataSource implements DataSource {
  final String apiEndpoint;

  WindexDataSource({required this.apiEndpoint});

  @override
  String get name => 'windex';

  @override
  Future<List<SourceResult>> search(IntentResult intent) async {
    // Simplified implementation - would use actual API call
    return [
      SourceResult(
        title: 'שיעור לדוגמה',
        teacher: intent.teacher,
        source: name,
        score: 0.9,
        snippet: 'תוכן השיעור...',
        metadata: {'lesson_post_id': '12345'},
      ),
    ];
  }
}