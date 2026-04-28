import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Map<String, Uint8List?> _cache = {};

  Future<Uint8List?> getImage(String path) async {
    if (_cache.containsKey(path)) return _cache[path];

    try {
      final metadata = await MetadataRetriever.fromFile(File(path));
      _cache[path] = metadata.albumArt;
      return metadata.albumArt;
    } catch (_) {
      _cache[path] = null;
      return null;
    }
  }

  void clearCache() => _cache.clear();
}
