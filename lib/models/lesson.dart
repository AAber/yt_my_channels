import 'package:equatable/equatable.dart';

class Lesson extends Equatable {
  final String id;
  final String seriesId;
  final String name;
  final String url;
  final String slug;
  final String? mp4Url;
  final String? mp3Url;
  final String? vimeoUrl;
  final String? thumbnailUrl;
  final int? lessonNumber;
  final String? sourceId;

  const Lesson({
    required this.id,
    required this.seriesId,
    required this.name,
    required this.url,
    required this.slug,
    this.mp4Url,
    this.mp3Url,
    this.vimeoUrl,
    this.thumbnailUrl,
    this.lessonNumber,
    this.sourceId,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] ?? '',
      seriesId: json['series_id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      slug: json['slug'] ?? '',
      mp4Url: json['mp4_url'],
      mp3Url: json['mp3_url'],
      vimeoUrl: json['vimeo_url'],
      thumbnailUrl: json['thumbnail_url'],
      lessonNumber: json['lesson_number'],
      sourceId: json['source_id'] ?? 'bneidavid',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'series_id': seriesId,
      'name': name,
      'url': url,
      'slug': slug,
      'mp4_url': mp4Url,
      'mp3_url': mp3Url,
      'vimeo_url': vimeoUrl,
      'thumbnail_url': thumbnailUrl,
      'lesson_number': lessonNumber,
      'source_id': sourceId,
    };
  }

  bool get hasMp4 => mp4Url != null && mp4Url!.isNotEmpty;

  bool get hasVimeo => vimeoUrl != null && vimeoUrl!.isNotEmpty;

  /// True when the lesson has playable video (mp4 or vimeo).
  bool get hasVideo => hasMp4 || hasVimeo;

  bool get hasAudio => mp3Url != null && mp3Url!.isNotEmpty;

  Lesson copyWith({
    String? name,
    String? mp4Url,
    String? mp3Url,
    String? vimeoUrl,
    String? thumbnailUrl,
  }) {
    return Lesson(
      id: id,
      seriesId: seriesId,
      name: name ?? this.name,
      url: url,
      slug: slug,
      mp4Url: mp4Url ?? this.mp4Url,
      mp3Url: mp3Url ?? this.mp3Url,
      vimeoUrl: vimeoUrl ?? this.vimeoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      lessonNumber: lessonNumber,
      sourceId: sourceId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        seriesId,
        name,
        url,
        slug,
        mp4Url,
        mp3Url,
        vimeoUrl,
        thumbnailUrl,
        lessonNumber,
        sourceId,
      ];
}
