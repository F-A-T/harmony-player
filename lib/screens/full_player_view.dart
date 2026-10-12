import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/player_provider.dart';
import '../services/image_cache_service.dart';
import 'dart:typed_data';

class FullPlayerView extends StatelessWidget {
  const FullPlayerView({super.key});

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  void _showLyrics(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(children: [
                const Icon(Icons.lyrics_rounded, color: Color(0xFF8E24AA)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context))
              ]),
              const Divider(color: Colors.white12),
              Expanded(
                child: FutureBuilder<String>(
                  future: Provider.of<PlayerProvider>(context, listen: false)
                      .getLyrics(title),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF8E24AA)));
                    } else if (snapshot.hasError || !snapshot.hasData) {
                      return const Center(
                          child: Text("Sözler yüklenemedi.",
                              style: TextStyle(color: Colors.white54)));
                    }
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: SelectableText(
                          snapshot.data!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16, height: 1.8, color: Colors.white70),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerProvider>();
    final song = provider.currentSong;

    if (song == null) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF141416),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Taban Katman: Kesinlikle arka ekranı göstermeyen opak taban ─
          Container(color: const Color(0xFF141416)),

          // ── Arka Plan: Kapak Resminin Bulanık Hali ──────────────────────
          _BlurredBackground(song: song),

          // ── Karanlık Overlay ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF141416).withOpacity(0.75),
                  const Color(0xFF141416).withOpacity(0.85),
                  const Color(0xFF141416).withOpacity(0.95),
                ],
              ),
            ),
          ),

          // ── İçerik ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                // ─ Üst Bar: Kapat butonu + Kaynak ─────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Column(
                        children: [
                          const Text("ŞİMDİ ÇALIYOR",
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w600)),
                          Text(provider.currentSource,
                              style: const TextStyle(
                                  color: Color(0xFF8E24AA),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 24),
                        onPressed: () {
                          if (song.isLocal) {
                            Share.share('🎵 Şu an "${song.title}" dinliyorum!');
                          } else {
                            Share.share('🎵 Şu an "${song.title}" dinliyorum!\n\nDinlemek için: https://www.youtube.com/watch?v=${song.id}');
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // ─ Kapak Resmi ────────────────────────────────────────
                Container(
                  width: screenWidth * 0.78,
                  height: screenWidth * 0.78,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _AlbumArt(song: song),
                  ),
                ),

                const Spacer(flex: 1),

                // ─ Şarkı Bilgisi ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        song.author,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.white54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─ İlerleme Çubuğu ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: StreamBuilder<Duration>(
                    stream: provider.audioService.positionStream,
                    builder: (context, posSnapshot) {
                      final pos = posSnapshot.data ?? Duration.zero;
                      return StreamBuilder<Duration?>(
                        stream: provider.audioService.durationStream,
                        builder: (context, durSnapshot) {
                          final duration =
                              durSnapshot.data ?? song.duration ?? Duration.zero;
                          final maxVal = duration.inSeconds.toDouble() > 0
                              ? duration.inSeconds.toDouble()
                              : (pos.inSeconds.toDouble() + 1);

                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14),
                                  activeTrackColor: const Color(0xFF8E24AA),
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: const Color(0xFF8E24AA),
                                  overlayColor:
                                      const Color(0xFF8E24AA).withOpacity(0.2),
                                ),
                                child: Slider(
                                  value:
                                      pos.inSeconds.toDouble().clamp(0.0, maxVal),
                                  max: maxVal,
                                  onChanged: (val) => provider.audioService
                                      .seek(Duration(seconds: val.toInt())),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(pos),
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12)),
                                    Text(_formatDuration(duration),
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // ─ Kontroller ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Shuffle
                      IconButton(
                        icon: Icon(Icons.shuffle_rounded,
                            color: provider.isShuffle
                                ? const Color(0xFF8E24AA)
                                : Colors.white54,
                            size: 24),
                        onPressed: () =>
                            provider.toggleShuffle(provider.currentSource),
                      ),
                      // Önceki
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded,
                            color: Colors.white, size: 38),
                        onPressed: () => provider.prevSong(),
                      ),
                      // Oynat / Duraklat
                      GestureDetector(
                        onTap:
                            provider.isLoading ? null : () => provider.togglePlay(),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF8E24AA),
                          ),
                          child: provider.isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : Icon(
                                  provider.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 38),
                        ),
                      ),
                      // Sonraki
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded,
                            color: Colors.white, size: 38),
                        onPressed: () => provider.nextSong(),
                      ),
                      // Loop
                      IconButton(
                        icon: Icon(
                          provider.loopMode == LoopMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: provider.loopMode == LoopMode.off
                              ? Colors.white54
                              : const Color(0xFF8E24AA),
                          size: 24,
                        ),
                        onPressed: () =>
                            provider.toggleLoopMode(provider.currentSource),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─ Alt butonlar: Lyrics ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            _showLyrics(context, song.title),
                        icon: const Icon(Icons.lyrics_rounded,
                            color: Colors.white54, size: 20),
                        label: const Text("Sözler",
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Arka Plan Widget'ı ─────────────────────────────────────────────────────
class _BlurredBackground extends StatelessWidget {
  final dynamic song;
  const _BlurredBackground({required this.song});

  @override
  Widget build(BuildContext context) {
    if (song.thumbnailUrl.startsWith('http')) {
      return RepaintBoundary(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Image.network(
            song.thumbnailUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0D1B2A)),
          ),
        ),
      );
    }
    // Yerel dosyalar için gömülü albüm resmini kullan
    return FutureBuilder<Uint8List?>(
      future: ImageCacheService().getImage(song.id),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return RepaintBoundary(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          );
        }
        // Albüm resmi yoksa gradient arka plan
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1B2A), Color(0xFF1B2838), Color(0xFF16213E)],
            ),
          ),
        );
      },
    );
  }
}

// ─── Albüm Kapağı Widget'ı ──────────────────────────────────────────────────
class _AlbumArt extends StatelessWidget {
  final dynamic song;
  const _AlbumArt({required this.song});

  @override
  Widget build(BuildContext context) {
    if (song.thumbnailUrl.startsWith('http')) {
      return Image.network(
        song.thumbnailUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF1E1E1E),
          child: const Icon(Icons.music_note_rounded,
              color: Color(0xFF8E24AA), size: 80),
        ),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: ImageCacheService().getImage(song.id),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return Container(
          color: const Color(0xFF1E1E1E),
          child: const Icon(Icons.music_note_rounded,
              color: Color(0xFF8E24AA), size: 80),
        );
      },
    );
  }
}
