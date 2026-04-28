import 'dart:convert';
import 'dart:io';
import '../services/download_service.dart';

class PlaylistService {
  final DownloadService _downloadService = DownloadService();

  Future<File> _getFile() async {
    final path = await _downloadService.getDownloadDirectory();
    return File('$path/playlists.json');
  }

  Future<Map<String, List<String>>> loadPlaylists() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return {};
      final jsonStr = await file.readAsString();
      final Map<String, dynamic> raw = jsonDecode(jsonStr);
      return raw.map((key, value) => MapEntry(key, List<String>.from(value)));
    } catch (_) {
      return {};
    }
  }

  Future<void> savePlaylists(Map<String, List<String>> playlists) async {
    try {
      final file = await _getFile();
      final jsonStr = jsonEncode(playlists);
      await file.writeAsString(jsonStr);
    } catch (_) {}
  }

  Future<void> addSongToPlaylist(String playlistName, String songPath) async {
    final playlists = await loadPlaylists();
    if (!playlists.containsKey(playlistName)) playlists[playlistName] = [];
    if (!playlists[playlistName]!.contains(songPath)) {
      playlists[playlistName]!.add(songPath);
      await savePlaylists(playlists);
    }
  }

  Future<void> deletePlaylist(String playlistName) async {
    final playlists = await loadPlaylists();
    if (playlists.containsKey(playlistName)) {
      playlists.remove(playlistName);
      await savePlaylists(playlists);
    }
  }
}
