import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/player_provider.dart';
import 'dart:io';
import '../services/image_cache_service.dart';
import 'dart:typed_data';

class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showLyrics(BuildContext context, String title, String author) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(children: [
                const Icon(Icons.lyrics, color: Color(0xFF1DB954)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context))
              ]),
              const Divider(color: Colors.white24),
              Expanded(
                child: FutureBuilder<String>(
                  future: Provider.of<PlayerProvider>(context, listen: false)
                      .getLyrics(title),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF1DB954)));
                    } else if (snapshot.hasError || !snapshot.hasData) {
                      return const Center(child: Text("Sözler yüklenemedi."));
                    }
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: SelectableText(
                          snapshot.data!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, height: 1.5),
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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<Duration>(
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
                      : (pos.inSeconds.toDouble() + 1).toDouble();

                  return Column(
                    children: [
                      Slider(
                        value: pos.inSeconds.toDouble().clamp(0.0, maxVal),
                        max: maxVal,
                        activeColor: const Color(0xFF1DB954),
                        inactiveColor: const Color(0xFF404040),
                        onChanged: (val) => provider.audioService
                            .seek(Duration(seconds: val.toInt())),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(pos),
                                style: const TextStyle(
                                    color: Color(0xFFB3B3B3), fontSize: 10)),
                            Text(_formatDuration(duration),
                                style: const TextStyle(
                                    color: Color(0xFFB3B3B3), fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showLyrics(context, song.title, song.author),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: song.thumbnailUrl.startsWith('http')
                      ? Image.network(song.thumbnailUrl,
                          width: 45,
                          height: 45,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.music_note,
                              color: Color(0xFF1DB954),
                              size: 45))
                      : FutureBuilder<Uint8List?>(
                          future: ImageCacheService().getImage(song.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Container(
                                  width: 45,
                                  height: 45,
                                  color: const Color(0xFF2B2B2B),
                                  child: const Icon(Icons.music_note,
                                      color: Color(0xFF555555), size: 20));
                            }
                            if (snapshot.hasData && snapshot.data != null) {
                              return Image.memory(snapshot.data!,
                                  width: 45, height: 45, fit: BoxFit.cover);
                            }
                            return Container(
                                width: 45,
                                height: 45,
                                color: const Color(0xFF1E1E1E),
                                child: const Icon(Icons.music_note,
                                    color: Color(0xFF1DB954), size: 45));
                          },
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      provider.isLoading
                          ? "Yükleniyor..."
                          : "${song.author} • ${provider.currentSource}",
                      style: const TextStyle(
                          color: Color(0xFF1DB954),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 32,
                onPressed: () => provider.prevSong(),
              ),
              IconButton(
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Color(0xFF1DB954), strokeWidth: 2))
                    : Icon(provider.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled),
                iconSize: 45,
                color: Colors.white,
                onPressed:
                    provider.isLoading ? null : () => provider.togglePlay(),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 32,
                onPressed: () => provider.nextSong(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
