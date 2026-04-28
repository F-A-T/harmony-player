import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../services/audio_service.dart';
import '../services/youtube_service.dart';
import '../services/lyrics_service.dart';
import '../main.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

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

  PlayerProvider() {
    _initAudioService();
  }

  Future<void> _initAudioService() async {
    await Permission.notification.request();
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

      // Auto-play next song on completion
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
  }

  void setPlaylist(List<Song> songs, int index, {String source = "Kitaplık"}) {
    _playlist = songs;
    _currentIndex = index;
    _currentSource = source;
    _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (currentSong == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      if (currentSong!.isLocal) {
        await _audioService.playLocalFile(currentSong!);
      } else {
        // Fetch valid stream URL
        final streamUrl = await _youtubeService.getStreamUrl(currentSong!.id);
        if (streamUrl != null) {
          await _audioService.playStream(streamUrl, currentSong!);
        } else {
          globalSnackbarKey.currentState?.showSnackBar(const SnackBar(
              content: Text("Stream URL alınamadı! (Youtube engellemesi)")));
        }
      }
    } catch (e) {
      globalSnackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text("Oynatma Hatası: \${e.toString()}")));
    } finally {
      // Always reset loading regardless of success/error
      _isLoading = false;
      notifyListeners();
    }
  }

  void togglePlay() {
    if (_isPlaying) {
      _audioService.pause();
    } else {
      _audioService.play();
    }
  }

  void nextSong() {
    if (_playlist.isEmpty) return;
    final currentShuffle = isShuffle;
    if (currentShuffle) {
      if (_playlist.length > 1) {
        int newIndex = _currentIndex;
        while (newIndex == _currentIndex) {
          newIndex = Random().nextInt(_playlist.length);
        }
        _currentIndex = newIndex;
      }
    } else {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }
    _playCurrent();
  }

  void prevSong() {
    if (_playlist.isEmpty) return;
    final currentShuffle = isShuffle;
    if (currentShuffle) {
      if (_playlist.length > 1) {
        int newIndex = _currentIndex;
        while (newIndex == _currentIndex) {
          newIndex = Random().nextInt(_playlist.length);
        }
        _currentIndex = newIndex;
      }
    } else {
      _currentIndex =
          (_currentIndex - 1) < 0 ? _playlist.length - 1 : (_currentIndex - 1);
    }
    _playCurrent();
  }

  void toggleShuffle(String viewSource) {
    if (viewSource == "Kitaplık") {
      _libraryIsShuffle = !_libraryIsShuffle;
    } else {
      _playlistIsShuffle = !_playlistIsShuffle;
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

  Future<String> getLyrics(String title) {
    return _lyricsService.fetchLyrics(title);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _audioService.dispose();
    _youtubeService.dispose();
    super.dispose();
  }
}
