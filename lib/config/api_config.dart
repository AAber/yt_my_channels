/// API Configuration
class ApiConfig {
  // Your GCP server
  static const String baseUrl = 'https://david.isaac770.live/api/v1';
  
  // Endpoints
  static const String series = '/series';
  static const String recentLessons = '/lessons/recent';
  static const String lessons = '/lessons';
  static const String scrape = '/scrape';
  
  // Full URLs
  static String getSeriesUrl() => '$baseUrl$series';
  static String getSeriesLessonsUrl(String slug) => '$baseUrl$series/$slug';
  static String getLessonUrl(String slug) => '$baseUrl$lessons/$slug';
  static String getRecentLessonsUrl({int limit = 20}) =>
      '$baseUrl$recentLessons?limit=$limit';

  static String getScanRecentUrl({int limit = 20}) =>
      '$baseUrl/lessons/scan_recent?limit=$limit';
  static String getScrapeUrl() => '$baseUrl$scrape';
}
