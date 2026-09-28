import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../services/logger_service.dart';
import '../services/youtube_service.dart';

class DownloadService {
  final YoutubeService _ytService = YoutubeService();
  static const MethodChannel _channel =
      MethodChannel('com.example.harmony_player/youtube');

  Future<String> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
      if (await Permission.manageExternalStorage.request().isGranted ||
          await Permission.storage.request().isGranted) {
        final dir = Directory('/storage/emulated/0/Download/Muziklerim');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir.path;
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    final target = Directory('${dir.path}/Muziklerim');
    if (!await target.exists()) await target.create(recursive: true);
    return target.path;
  }

  Future<List<FileSystemEntity>> getLocalAudioFiles() async {
    try {
      final path = await getDownloadDirectory();
      final dir = Directory(path);
      if (await dir.exists()) {
        final files = dir.listSync().where((item) {
          final p = item.path.toLowerCase();
          return p.endsWith('.mp3') || p.endsWith('.m4a');
        }).toList();
        files.sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        return files;
      }
    } catch (e) {
      print("Okuma hatası: $e");
    }
    return [];
  }

  Future<bool> downloadAudio(
      String videoId, String title, String thumbnailUrl) async {
    final logger = LoggerService();
    int retries = 3;

    for (int i = 0; i < retries; i++) {
      try {
        final path = await getDownloadDirectory();
        final safeTitle = title.replaceAll(RegExp(r'[/\\|?*:"<>]'), '');
        final downloadPath = '$path/$safeTitle.mp3';

        final file = File(downloadPath);

        if (await file.exists() && await file.length() > 500000) return true;

        await logger.log("İndirme denemesi ${i + 1}/$retries: $title");

        final result = await _channel.invokeMethod(
            'downloadAudio', {'videoId': videoId, 'downloadPath': downloadPath});

        if (await file.exists() && await file.length() < 10000) {
          await logger.log("İndirme hatası: Dosya çok küçük (0 byte) - $title", type: "ERROR");
          await file.delete();
          continue; // Retry
        }

        if (result == true) {
          await logger.log("İndirme başarılı: $title", type: "SUCCESS");
          return true;
        } else {
          await logger.log("Native Bridge false döndürdü - $title", type: "WARN");
        }
      } catch (e) {
        await logger.log("İndirme hatası ($title): $e", type: "ERROR");
      }
      await Future.delayed(const Duration(seconds: 2)); // Wait before retry
    }
    
    await logger.log("Tüm indirme denemeleri başarısız oldu: $title", type: "CRITICAL");
    return false;
  }

  void dispose() {}
}
