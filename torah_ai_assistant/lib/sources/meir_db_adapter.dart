// This adapter is deprecated - use MeirApiAdapter instead
// Keeping for reference only

import '../agent/models.dart';
import 'data_source.dart';

class MeirDbAdapter implements DataSource {
  final String dbPath;

  MeirDbAdapter({required this.dbPath});

  @override
  String get name => 'meir_db_deprecated';

  @override
  Future<List<SourceResult>> search(IntentResult intent) async {
    // Deprecated - use MeirApiAdapter
    return [];
  }

  Future<void> close() async {
    // No-op
  }
}