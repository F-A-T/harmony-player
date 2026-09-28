import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/full_player_view.dart';
import '../services/image_cache_service.dart';
import 'dart:typed_data';

class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerProvider>();
    final song = provider.currentSong;

    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const SizedBox(
            height: double.infinity,
            child: FullPlayerView(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Mini ilerleme çubuğu (ince çizgi) ─────────────────────
            StreamBuilder<Duration>(
              stream: provider.audioService.positionStream,
              builder: (context, posSnapshot) {
                final pos = posSnapshot.data ?? Duration.zero;
                return StreamBuilder<Duration?>(
                  stream: provider.audioService.durationStream,
                  builder: (context, durSnapshot) {
                    final duration =
                        durSnapshot.data ?? song.duration ?? Duration.zero;
                    final progress = duration.inMilliseconds > 0
                        ? (pos.inMilliseconds / duration.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0;

                    return ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(14)),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2.5,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF1DB954)),
                      ),
                    );
                  },
                );
              },
            ),

            // ── İçerik ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  // Kapak resmi
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: _MiniAlbumArt(song: song),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Şarkı adı ve yazar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.isLoading
                              ? "Yükleniyor..."
                              : song.author,
                          style: TextStyle(
                              color: provider.isLoading
                                  ? const Color(0xFF1DB954)
                                  : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Oynat / Duraklat
                  IconButton(
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Color(0xFF1DB954), strokeWidth: 2))
                        : Icon(
                            provider.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30),
                    onPressed: provider.isLoading
                        ? null
                        : () => provider.togglePlay(),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),

                  // Sonraki şarkı
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded,
                        color: Colors.white70, size: 26),
                    onPressed: () => provider.nextSong(),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mini Kapak Resmi ───────────────────────────────────────────────────────
class _MiniAlbumArt extends StatelessWidget {
  final dynamic song;
  const _MiniAlbumArt({required this.song});

  @override
  Widget build(BuildContext context) {
    if (song.thumbnailUrl.startsWith('http')) {
      return Image.network(
        song.thumbnailUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF2B2B2B),
          child: const Icon(Icons.music_note_rounded,
              color: Color(0xFF1DB954), size: 24),
        ),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: ImageCacheService().getImage(song.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
              color: const Color(0xFF2B2B2B),
              child: const Icon(Icons.music_note,
                  color: Color(0xFF555555), size: 20));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return Container(
            color: const Color(0xFF1E1E1E),
            child: const Icon(Icons.music_note_rounded,
                color: Color(0xFF1DB954), size: 24));
      },
    );
  }
}
