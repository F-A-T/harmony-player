import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
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
    try {
      final path = await getDownloadDirectory();
      final safeTitle = title.replaceAll(RegExp(r'[/\\|?*:"<>]'), '');
      final downloadPath = '$path/$safeTitle.mp3';

      final file = File(downloadPath);
      final imageFile = File('$path/$safeTitle.jpg');

      if (await file.exists() && await file.length() > 500000) return true;

      // Native Kotlin yt-dlp köprüsüne indirme emri gönderiyoruz (ffmpeg metaverilerini gömer)
      final result = await _channel.invokeMethod(
          'downloadAudio', {'videoId': videoId, 'downloadPath': downloadPath});

      // İndirme bittiğinde boyut kontrolü (0 byte koruması)
      if (await file.length() < 10000) {
        print("Hata: Dosya çok küçük (0 byte sorunu)");
        if (await file.exists()) await file.delete();
        return false;
      }

      return result == true;
    } catch (e) {
      print("İndirme sırasında hata oluştu: $e");
      return false;
    }
  }

  void dispose() {}
}
