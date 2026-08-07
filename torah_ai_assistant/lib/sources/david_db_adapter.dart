// This adapter is deprecated - use DavidApiAdapter instead
// Keeping for reference only

import '../agent/models.dart';
import 'data_source.dart';

class DavidDbAdapter implements DataSource {
  final String dbPath;

  DavidDbAdapter({required this.dbPath});

  @override
  String get name => 'david_db_deprecated';

  @override
  Future<List<SourceResult>> search(IntentResult intent) async {
    // Deprecated - use DavidApiAdapter
    return [];
  }

  Future<void> close() async {
    // No-op
  }
}