import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../services/audio_service.dart';
import '../services/youtube_service.dart';
import '../services/lyrics_service.dart';
import '../main.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:async';

class PlayerProvider with ChangeNotifier {
  final AudioService _audioService = AudioService();
  final YoutubeService _youtubeService = YoutubeService();
  final LyricsService _lyricsService = LyricsService();

  List<Song> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = false;
  String _currentSource = "Bilinmiyor";
  LoopMode _libraryLoopMode = LoopMode.off;
  bool _libraryIsShuffle = false;
  LoopMode _playlistLoopMode = LoopMode.off;
  bool _playlistIsShuffle = false;

  // ─── Akıllı Shuffle ─────────────────────────────────────────────────────────
  // Henüz çalınmamış indeksler kuyruğu
  List<int> _unplayedIndices = [];
  // Geri tuşu için çalınmış şarkıların geçmiş indeksleri
  List<int> _shuffleHistory = [];

  // ─── Getters ────────────────────────────────────────────────────────────────
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  Song? get currentSong => _playlist.isEmpty ? null : _playlist[_currentIndex];
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get currentSource => _currentSource;
  LoopMode get loopMode =>
      _currentSource == "Kitaplık" ? _libraryLoopMode : _playlistLoopMode;
  bool get isShuffle =>
      _currentSource == "Kitaplık" ? _libraryIsShuffle : _playlistIsShuffle;

  LoopMode get libraryLoopMode => _libraryLoopMode;
  bool get libraryIsShuffle => _libraryIsShuffle;
  LoopMode get playlistLoopMode => _playlistLoopMode;
  bool get playlistIsShuffle => _playlistIsShuffle;
  AudioService get audioService => _audioService;
  YoutubeService get youtubeService => _youtubeService;

  // ─── Uyku Zamanlayıcısı (Sleep Timer) ──────────────────────────────────────
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;

  bool get hasActiveSleepTimer => _sleepTimer != null && _sleepTimer!.isActive;
  Duration? get remainingSleepTime {
    if (_sleepTimerEndTime == null || !hasActiveSleepTimer) return null;
    final diff = _sleepTimerEndTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void pause() => _audioService.pause();
  void play() => _audioService.play();

  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      _audioService.pause();
      cancelSleepTimer();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    notifyListeners();
  }

  PlayerProvider() {
    _initAudioService();
  }

  Future<void> _initAudioService() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await Permission.notification.request();
    }
    await _audioService.init();
    _audioService.setCallbacks(
      onNext: () => nextSong(),
      onPrevious: () => prevSong(),
    );
    _audioService.playerStateStream.listen((state) {
      _isPlaying = state.playing;

      if (_isPlaying) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }

      if (state.processingState == ProcessingState.completed) {
        final currentLoopMode = loopMode;
        if (currentLoopMode == LoopMode.all) {
          _audioService.seek(Duration.zero);
          _audioService.play();
        } else if (currentLoopMode == LoopMode.one) {
          if (_currentSource == "Kitaplık") {
            _libraryLoopMode = LoopMode.off;
          } else {
            _playlistLoopMode = LoopMode.off;
          }
          _audioService.seek(Duration.zero);
          _audioService.play();
          notifyListeners();
        } else {
          nextSong();
        }
      }
      notifyListeners();
    });

    // Uygulamada önceki oturumu geri yükle
    await _restoreLastSession();
  }

  // ─── Playlist Yönetimi ───────────────────────────────────────────────────────
  void setPlaylist(List<Song> songs, int index, {String source = "Kitaplık"}) {
    _playlist = songs;
    _currentIndex = index;
    _currentSource = source;
    _resetShuffleQueue(); // Yeni liste başlayınca shuffle kuyruğunu sıfırla
    _playCurrent();
  }

  // ─── Akıllı Shuffle Kuyruk Yönetimi ─────────────────────────────────────────
  void _resetShuffleQueue() {
    _shuffleHistory.clear();
    _unplayedIndices = List.generate(_playlist.length, (i) => i)
      ..remove(_currentIndex) // Mevcut şarkı zaten çalıyor, listeden çıkar
      ..shuffle();
  }

  // ─── Oynatma ────────────────────────────────────────────────────────────────
  Future<void> _playCurrent() async {
    if (currentSong == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      if (currentSong!.isLocal) {
        await _audioService.playLocalFile(currentSong!);
      } else {
        await _playWithRetry(currentSong!);
      }
      // Başarıyla çalınca oturumu kaydet
      _saveLastSession();
    } catch (e) {
      globalSnackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text("Oynatma Hatası: ${e.toString()}")));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// YouTube şarkısı için: hata olursa stream URL'i yeniler, 2 kez dener.
  Future<void> _playWithRetry(Song song) async {
    Exception? lastError;
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final streamUrl = await _youtubeService.getStreamUrl(song.id);
        if (streamUrl == null) {
          throw Exception("Stream URL alınamadı (YouTube engellemesi olabilir)");
        }
        await _audioService.playStream(streamUrl, song);
        return; // Başarılıysa çık
      } catch (e) {
        lastError = Exception(e.toString());
        if (attempt < 2) {
          // İlk denemede hata alındıysa kısa bekle ve tekrar dene
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    // 2 denemede de başarısız olunduysa hatayı yukarıya ilet
    throw lastError!;
  }

  void togglePlay() {
    if (_isPlaying) {
      _audioService.pause();
      _saveLastSession();
    } else {
      _audioService.play();
    }
  }

  // ─── Sonraki / Önceki Şarkı ─────────────────────────────────────────────────
  void nextSong() {
    if (_playlist.isEmpty) return;

    if (isShuffle) {
      // Mevcut şarkıyı geçmişe ekle
      _shuffleHistory.add(_currentIndex);

      if (_unplayedIndices.isEmpty) {
        // Tüm şarkılar çalındı, kuyruğu yenile
        _resetShuffleQueue();
      }

      if (_unplayedIndices.isNotEmpty) {
        _currentIndex = _unplayedIndices.removeLast();
      }
    } else {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }
    _playCurrent();
  }

  void prevSong() {
    if (_playlist.isEmpty) return;

    if (isShuffle) {
      // Shuffle modunda geri: gerçek geçmişten al
      if (_shuffleHistory.isNotEmpty) {
        // Mevcut şarkıyı çalınmamışlar listesine geri koy
        _unplayedIndices.add(_currentIndex);
        _currentIndex = _shuffleHistory.removeLast();
      }
      // Geçmiş boşsa (ilk şarkı) aynı şarkıda kal
    } else {
      _currentIndex =
          (_currentIndex - 1) < 0 ? _playlist.length - 1 : (_currentIndex - 1);
    }
    _playCurrent();
  }

  // ─── Shuffle / Loop Toggle ───────────────────────────────────────────────────
  void toggleShuffle(String viewSource) {
    if (viewSource == "Kitaplık") {
      _libraryIsShuffle = !_libraryIsShuffle;
      if (_libraryIsShuffle) _resetShuffleQueue();
    } else {
      _playlistIsShuffle = !_playlistIsShuffle;
      if (_playlistIsShuffle) _resetShuffleQueue();
    }
    notifyListeners();
  }

  void toggleLoopMode(String viewSource) {
    final currentLoopMode = loopMode;
    LoopMode nextMode;
    if (currentLoopMode == LoopMode.off) {
      nextMode = LoopMode.all;
    } else if (currentLoopMode == LoopMode.all) {
      nextMode = LoopMode.one;
    } else {
      nextMode = LoopMode.off;
    }

    if (viewSource == "Kitaplık") {
      _libraryLoopMode = nextMode;
    } else {
      _playlistLoopMode = nextMode;
    }
    notifyListeners();
  }

  // ─── Oturum Kaydetme / Geri Yükleme ────────────────────────────────────────
  Future<void> _saveLastSession() async {
    if (_playlist.isEmpty || currentSong == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Sadece yerel şarkıların konumunu kaydediyoruz (YouTube URL'leri süresinin
      // dolması nedeniyle kaydetmenin anlamı yok, sadece şarkı bilgisi kaydedilir)
      final position = await _audioService.getCurrentPosition();
      await prefs.setString('last_song_id', currentSong!.id);
      await prefs.setString('last_song_title', currentSong!.title);
      await prefs.setString('last_song_author', currentSong!.author);
      await prefs.setString('last_song_thumbnail', currentSong!.thumbnailUrl);
      await prefs.setBool('last_song_is_local', currentSong!.isLocal);
      await prefs.setString('last_source', _currentSource);
      await prefs.setInt('last_position_ms', position.inMilliseconds);

      // Tüm playlist'i JSON olarak kaydet (sadece yerel playlist ise)
      if (_playlist.every((s) => s.isLocal)) {
        final playlistJson = jsonEncode(
          _playlist.map((s) => {
            'id': s.id,
            'title': s.title,
            'author': s.author,
            'thumbnailUrl': s.thumbnailUrl,
            'isLocal': s.isLocal,
          }).toList(),
        );
        await prefs.setString('last_playlist_json', playlistJson);
        await prefs.setInt('last_playlist_index', _currentIndex);
      }
    } catch (e) {
      // Kaydetme hataları uygulamayı durdurmamalı
    }
  }

  Future<void> _restoreLastSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistJson = prefs.getString('last_playlist_json');
      final savedIndex = prefs.getInt('last_playlist_index') ?? 0;
      final positionMs = prefs.getInt('last_position_ms') ?? 0;
      final savedSource = prefs.getString('last_source') ?? "Kitaplık";

      if (playlistJson != null && playlistJson.isNotEmpty) {
        final List<dynamic> rawList = jsonDecode(playlistJson);
        final restoredPlaylist = rawList.map((m) => Song(
          id: m['id'],
          title: m['title'],
          author: m['author'],
          thumbnailUrl: m['thumbnailUrl'],
          isLocal: m['isLocal'] ?? true,
          duration: null,
        )).toList();

        if (restoredPlaylist.isNotEmpty) {
          _playlist = restoredPlaylist;
          _currentIndex = savedIndex.clamp(0, restoredPlaylist.length - 1);
          _currentSource = savedSource;
          _resetShuffleQueue();

          // Yerel şarkıyı sessizce hazırla (otomatik oynatma yok)
          if (currentSong!.isLocal) {
            await _audioService.prepareLocalFile(currentSong!);
            // Kaydedilen konuma git
            if (positionMs > 0) {
              await Future.delayed(const Duration(milliseconds: 500));
              await _audioService.seek(Duration(milliseconds: positionMs));
            }
            notifyListeners();
          }
        }
      }
    } catch (e) {
      // Geri yükleme hataları sessizce yutulur
    }
  }

  // ─── Şarkı Sözleri ──────────────────────────────────────────────────────────
  Future<String> getLyrics(String title) {
    return _lyricsService.fetchLyrics(title);
  }

  // ─── Dispose ────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _sleepTimer?.cancel();
    WakelockPlus.disable();
    _audioService.dispose();
    _youtubeService.dispose();
    super.dispose();
  }
}
