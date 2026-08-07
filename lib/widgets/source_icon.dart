import 'package:flutter/material.dart';
import '../models/source.dart';

class SourceIcon extends StatelessWidget {
  final String? sourceId;
  final double size;
  final Widget? fallback;

  const SourceIcon({
    super.key,
    this.sourceId,
    this.size = 40,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final source = Sources.getById(sourceId ?? 'bneidavid');
    
    if (source == null) {
      return fallback ?? Icon(Icons.school, size: size);
    }

    return Image.asset(
      source.iconPath,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) {
        return fallback ?? Icon(Icons.school, size: size);
      },
    );
  }
}
