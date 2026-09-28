import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart' as as_service;
import '../models/song.dart';
import '../main.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path_provider/path_provider.dart';

class MyAudioHandler extends as_service.BaseAudioHandler
    with as_service.QueueHandler, as_service.SeekHandler {
  final AudioPlayer _player;
  void Function()? onNext;
  void Function()? onPrevious;

  MyAudioHandler(this._player) {
    _player.playbackEventStream.listen(_broadcastState);
  }

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        as_service.MediaControl.skipToPrevious,
        if (_player.playing)
          as_service.MediaControl.pause
        else
          as_service.MediaControl.play,
        as_service.MediaControl.skipToNext,
      ],
      systemActions: const {
        as_service.MediaAction.seek,
        as_service.MediaAction.seekForward,
        as_service.MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: as_service.AudioProcessingState.idle,
        ProcessingState.loading: as_service.AudioProcessingState.loading,
        ProcessingState.buffering: as_service.AudioProcessingState.buffering,
        ProcessingState.ready: as_service.AudioProcessingState.ready,
        ProcessingState.completed: as_service.AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  @override
  Future<void> skipToNext() async => onNext?.call();

  @override
  Future<void> skipToPrevious() async => onPrevious?.call();
}

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  late MyAudioHandler _handler;
  bool _isHandlerInitialized = false;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  void setCallbacks({void Function()? onNext, void Function()? onPrevious}) {
    if (_isHandlerInitialized) {
      _handler.onNext = onNext;
      _handler.onPrevious = onPrevious;
    }
  }

  Future<void> init() async {
    try {
      _handler = await as_service.AudioService.init(
        builder: () => MyAudioHandler(_player),
        config: const as_service.AudioServiceConfig(
          androidNotificationChannelId: 'com.harmony.player.channel.audio',
          androidNotificationChannelName: 'Harmony Player Oynatma',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'drawable/ic_notification',
        ),
      );
      _isHandlerInitialized = true;
    } catch (e) {
      print("AudioService arka plan servisi başlatılamadı: $e");
      try {
        globalSnackbarKey.currentState
            ?.showSnackBar(SnackBar(content: Text("Panel Hatası: $e")));
      } catch (_) {}
      _isHandlerInitialized = false;
    }

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked:
          false, // Ensures volume lowers instead of pausing
    ));
  }

  Future<void> _updateMediaItem(Song song) async {
    Uri? artUri;
    if (song.thumbnailUrl.isNotEmpty) {
      if (song.thumbnailUrl.startsWith('http')) {
        artUri = Uri.parse(song.thumbnailUrl);
      } else if (File(song.thumbnailUrl).existsSync()) {
        artUri = Uri.file(song.thumbnailUrl);
      } else if (song.isLocal) {
        try {
          final metadata = await MetadataRetriever.fromFile(File(song.id));
          if (metadata.albumArt != null) {
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/thumb_${song.id.hashCode}.jpg');
            if (!tempFile.existsSync()) {
              await tempFile.writeAsBytes(metadata.albumArt!);
            }
            artUri = Uri.file(tempFile.path);
          }
        } catch (_) {}
      }
    }

    if (_isHandlerInitialized) {
      _handler.mediaItem.add(as_service.MediaItem(
        id: song.id.hashCode.toString(),
        album: "Harmony Player",
        title: song.title,
        artist: song.author,
        artUri: artUri,
      ));
    }
  }

  Future<void> playStream(String uri, Song song) async {
    try {
      await _updateMediaItem(song);
      await _player.setAudioSource(AudioSource.uri(
        Uri.parse(uri),
      ));
      _player.play();
    } catch (e) {
      print("AudioService playStream hatası: $e");
      rethrow;
    }
  }

  Future<void> playLocalFile(Song song) async {
    try {
      await _updateMediaItem(song);
      await _player.setAudioSource(AudioSource.uri(
        Uri.file(song.id),
      ));
      _player.play();
    } catch (e) {
      print("AudioService playLocalFile hatası: $e");
      rethrow;
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> stop() => _player.stop();
  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);

  /// Mevcut oynatma konumunu döner (oturum kaydetmek için kullanılır)
  Future<Duration> getCurrentPosition() async {
    return _player.position;
  }

  /// Şarkıyı oynatmadan sadece hazırlar (oturum geri yükleme için)
  Future<void> prepareLocalFile(Song song) async {
    try {
      await _updateMediaItem(song);
      await _player.setAudioSource(AudioSource.uri(Uri.file(song.id)));
    } catch (e) {
      print("prepareLocalFile hatası: $e");
    }
  }

  Future<void> dispose() => _player.dispose();
}
