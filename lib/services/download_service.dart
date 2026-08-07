import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

enum DownloadType { mp4, mp3 }

class DownloadedFile {
  final String title;
  final String filePath;
  final DownloadType type;
  final int sizeBytes;

  DownloadedFile({
    required this.title,
    required this.filePath,
    required this.type,
    required this.sizeBytes,
  });
}

class DownloadService {
  static final _dio = Dio();

  static Future<Directory> _downloadsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _safeFileName(String title, DownloadType type) {
    final clean = title.replaceAll(RegExp(r'[^\w\u0590-\u05FF ]'), '_').trim();
    final ext = type == DownloadType.mp4 ? 'mp4' : 'mp3';
    return '$clean.$ext';
  }

  /// Returns the local path if already downloaded, null otherwise.
  static Future<String?> localPath(String title, DownloadType type) async {
    final dir = await _downloadsDir();
    final file = File('${dir.path}/${_safeFileName(title, type)}');
    return (await file.exists()) ? file.path : null;
  }

  /// Downloads [url] and saves it. Calls [onProgress] with 0.0–1.0.
  static Future<String> download(
    String url,
    String title,
    DownloadType type, {
    void Function(double)? onProgress,
  }) async {
    final dir = await _downloadsDir();
    final savePath = '${dir.path}/${_safeFileName(title, type)}';
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );
    return savePath;
  }

  static Future<List<DownloadedFile>> listDownloads() async {
    final dir = await _downloadsDir();
    final files = await dir.list().toList();
    final result = <DownloadedFile>[];
    for (final f in files) {
      if (f is File) {
        final name = f.path.split('/').last;
        final isMp4 = name.endsWith('.mp4');
        final title = name.replaceAll(RegExp(r'\.(mp4|mp3)$'), '');
        final stat = await f.stat();
        result.add(DownloadedFile(
          title: title,
          filePath: f.path,
          type: isMp4 ? DownloadType.mp4 : DownloadType.mp3,
          sizeBytes: stat.size,
        ));
      }
    }
    result.sort((a, b) => a.title.compareTo(b.title));
    return result;
  }

  static Future<void> delete(String filePath) async {
    final f = File(filePath);
    if (await f.exists()) await f.delete();
  }
}
