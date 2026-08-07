import 'package:equatable/equatable.dart';

class Series extends Equatable {
  final String id;
  final String name;
  final String url;
  final String slug;
  final int lessonCount;
  final String? sourceId;

  const Series({
    required this.id,
    required this.name,
    required this.url,
    required this.slug,
    required this.lessonCount,
    this.sourceId,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      slug: json['slug'] ?? '',
      lessonCount: json['lesson_count'] ?? 0,
      sourceId: json['source_id'] ?? 'bneidavid',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'slug': slug,
      'lesson_count': lessonCount,
      'source_id': sourceId,
    };
  }

  @override
  List<Object?> get props => [id, name, url, slug, lessonCount, sourceId];
}
