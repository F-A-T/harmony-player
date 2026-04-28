import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/song.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;

class YoutubeService {
  final yte.YoutubeExplode _ytExplode = yte.YoutubeExplode();
  static const _channel = MethodChannel('com.example.harmony_player/youtube');

  Future<List<Song>> searchSongs(String query) async {
    try {
      final res = await http
          .get(Uri.parse(
              'https://pipedapi.kavin.rocks/search?q=${Uri.encodeComponent(query)}&filter=videos'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> items = data['items'];
        return items
            .map((item) => Song(
                  id: item['url'].toString().split('v=')[1],
                  title: item['title'],
                  author: item['uploaderName'] ?? "Bilinmiyor",
                  thumbnailUrl: item['thumbnail'] ?? "",
                  duration: null,
                  isLocal: false,
                ))
            .toList();
      }
    } catch (e) {
      print("Arama hatası: $e");
    }

    try {
      final results = await _ytExplode.search.search(query);
      return results.map((v) => Song.fromYouTube(v)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> getStreamUrl(String videoId) async {
    // 1. YÖNTEM: NATIVE BRIDGE (yt-dlp via youtubedl-android - EN SAĞLAMI MÜKEMMEL ÇÖZÜM)
    try {
      final String? streamUrl =
          await _channel.invokeMethod('getStreamUrl', {'videoId': videoId});
      if (streamUrl != null && streamUrl.isNotEmpty) {
        print("Native Bridge (yt-dlp) URL başarıyla alındı.");
        return streamUrl;
      }
    } catch (e) {
      print("Native Bridge hatası (Yedek yöntemlere geçiliyor): $e");
    }

    // 2. YÖNTEM: Cobalt API (Yedek)
    try {
      final res = await http
          .post(
            Uri.parse('https://api.cobalt.tools/api/json'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json'
            },
            body: json.encode({
              'url': 'https://www.youtube.com/watch?v=$videoId',
              'downloadMode': 'audio',
              'audioFormat': 'mp3',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'stream' || data['status'] == 'redirect')
          return data['url'];
      }
    } catch (_) {}

    // 3. YÖNTEM: YoutubeExplode (Son Çare)
    try {
      final manifest =
          await _ytExplode.videos.streamsClient.getManifest(videoId);
      final audioInfo = manifest.audioOnly.withHighestBitrate();
      if (audioInfo.url.toString().isNotEmpty) {
        print("YoutubeExplode stream URL başarıyla alındı.");
        return audioInfo.url.toString();
      }
    } catch (e) {
      print("YoutubeExplode stream hatası: $e");
    }

    return null;
  }

  Future<bool> downloadToPipe(String videoId, var output) async {
    try {
      final manifest =
          await _ytExplode.videos.streamsClient.getManifest(videoId);
      final audioInfo = manifest.audioOnly.withHighestBitrate();
      final stream = _ytExplode.videos.streamsClient.get(audioInfo);
      await stream.pipe(output);
      return true;
    } catch (e) {
      print("ytExplode indirme hatası: $e");
      return false;
    }
  }

  Future<List<Song>> getPlaylistVideos(String urlInfo) async {
    try {
      String playlistId = urlInfo;
      if (urlInfo.contains("list=")) {
        playlistId = urlInfo.split("list=")[1].split("&")[0];
      }
      final playlist = await _ytExplode.playlists.get(playlistId);
      final videos = await _ytExplode.playlists.getVideos(playlist.id).toList();
      return videos.map((v) => Song.fromYouTube(v)).toList();
    } catch (e) {
      print("YT Playlist Çekme Hatası: $e");
      return [];
    }
  }

  void dispose() {
    _ytExplode.close();
  }
}
