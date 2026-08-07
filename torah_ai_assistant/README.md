# Torah AI Assistant Setup

## Quick Integration Guide

### 1. Add to pubspec.yaml
```yaml
dependencies:
  torah_ai_assistant:
    path: ./torah_ai_assistant
```

### 2. Get Groq API Key
1. Visit https://console.groq.com/
2. Create account and get API key
3. Add to your app configuration

### 3. Database Setup
Copy your database files to the app's documents directory:
- `meir_unified.sqlite` (lessons database)
- `david.db` (books database)

### 4. Basic Integration
```dart
import 'package:torah_ai_assistant/torah_ai_assistant.dart';

// In your widget:
TorahChatWidget(
  agent: TorahAgent(
    config: AgentConfig(groqApiKey: 'your-api-key'),
    sources: [
      MeirDbAdapter(dbPath: '/path/to/meir_unified.sqlite'),
      DavidDbAdapter(dbPath: '/path/to/david.db'),
      SefariaAdapter(),
    ],
  ),
)
```

### 5. Database Schema Requirements

#### Meir DB (lessons) expected columns:
- `title` (TEXT) - Lesson title
- `teacher` (TEXT) - Rabbi name
- `book` (TEXT) - Torah book/tractate
- `parsha` (TEXT) - Weekly parsha
- `tags` (TEXT) - Comma-separated topics
- `duration_seconds` (INTEGER) - Lesson length
- `lesson_id` (INTEGER/TEXT) - Unique identifier
- `description` (TEXT) - Lesson description

#### David DB (books) expected columns:
- `title` (TEXT) - Book title
- `author` (TEXT) - Author name
- `category` (TEXT) - Book category
- `chapter_title` (TEXT) - Chapter name
- `content_preview` (TEXT) - Preview text
- `book_id` (INTEGER/TEXT) - Unique identifier

### 6. Features
- ✅ Natural language search in Hebrew/English
- ✅ Multi-source search (lessons + books + Sefaria)
- ✅ Warm, conversational responses
- ✅ RTL support for Hebrew
- ✅ Session persistence
- ✅ Source attribution with tappable chips
- ✅ Groq API integration (free tier)

### 7. Example Queries
- "מצא לי שיעור על שבת"
- "רוצה ללמוד עם הרב מזרחי"
- "חפש לי משהו על תפילה"
- "Find me a short lesson on Emunah"

### 8. Customization
```dart
ChatTheme(
  primaryColor: Colors.deepPurple,
  backgroundColor: Colors.grey[50]!,
  // ... other theme properties
)
```

## Environment Variables
Create a `.env` file or add to your app config:
```
GROQ_API_KEY=your_groq_api_key_here
```

## Database Path Helper
```dart
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<String> getDatabasePath(String dbName) async {
  final documentsDir = await getApplicationDocumentsDirectory();
  return join(documentsDir.path, dbName);
}
```