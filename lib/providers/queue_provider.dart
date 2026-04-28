import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/download_service.dart';
import '../services/youtube_service.dart';

class QueueItem {
  final String title;
  final String? artist;
  final String? videoId;
  String status; // "waiting", "downloading", "skipped", "completed", "error"

  QueueItem(
      {required this.title,
      this.artist,
      this.videoId,
      this.status = "waiting"});
}

class QueueProvider with ChangeNotifier {
  final List<QueueItem> _queue = [];
  bool _isProcessing = false;
  final DownloadService _downloadService = DownloadService();

  List<QueueItem> get queue => _queue;
  bool get isProcessing => _isProcessing;

  void addToQueue(String title, [String? artist, String? videoId]) {
    _queue.add(QueueItem(title: title, artist: artist, videoId: videoId));
    notifyListeners();
    if (!_isProcessing) {
      _processQueue();
    }
  }

  void addMultipleToQueue(List<QueueItem> items) {
    _queue.addAll(items);
    notifyListeners();
    if (!_isProcessing) {
      _processQueue();
    }
  }

  bool _cancelRequested = false;

  void clearQueue() {
    _queue.clear();
    _isProcessing = false;
    _cancelRequested = true;
    notifyListeners();
  }

  Future<void> _processQueue() async {
    _isProcessing = true;
    _cancelRequested = false;
    notifyListeners();
    WakelockPlus.enable();

    for (int i = 0; i < _queue.length; i++) {
      if (_cancelRequested) break;
      var item = _queue[i];
      if (item.status != "waiting") continue;

      item.status = "downloading";
      notifyListeners();

      // Check if file already exists before doing heavy network
      final pathDir = await _downloadService.getDownloadDirectory();
      final safeTitle = item.title.replaceAll(RegExp(r'[/\\|?*:"<>]'), '');
      final file = File('$pathDir/$safeTitle.mp3');

      if (await file.exists() && await file.length() > 500000) {
        item.status = "skipped"; // Zaten var!
        notifyListeners();
        continue;
      }

      String vid = item.videoId ?? "";
      if (vid.isEmpty) {
        // Need to search on Youtube for the videoId
        try {
          final searchResult = await YoutubeService()
              .searchSongs(item.title + " " + (item.artist ?? ""));
          if (searchResult.isNotEmpty) {
            vid = searchResult.first.id;
          } else {
            item.status = "error";
            notifyListeners();
            continue;
          }
        } catch (e) {
          item.status = "error";
          notifyListeners();
          continue;
        }
      }

      // Proceed to native download
      bool success = await _downloadService.downloadAudio(vid, item.title, "");
      if (_cancelRequested) break;
      if (success) {
        item.status = "completed";
      } else {
        item.status = "error";
      }
      notifyListeners();
    }

    _isProcessing = false;
    _cancelRequested = false;
    notifyListeners();
    WakelockPlus.disable();
  }
}
