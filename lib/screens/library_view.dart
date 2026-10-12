import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/download_service.dart';
import 'dart:io';
import '../main.dart';
import '../services/image_cache_service.dart';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../services/playlist_service.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  final DownloadService _downloadService = DownloadService();
  final PlaylistService _playlistService = PlaylistService();
  List<Song> _localSongs = [];
  bool _isLoading = true;

  // Arama
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLocalFiles();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalFiles() async {
    setState(() => _isLoading = true);
    final files = await _downloadService.getLocalAudioFiles();

    final songs = files.map((file) {
      final name = p.basenameWithoutExtension(file.path);
      final thumbPath = file.path.replaceAll(RegExp(r'\.(mp3|m4a)$'), '.jpg');
      return Song.fromLocal(file.path, name, thumbPath);
    }).toList();

    setState(() {
      _localSongs = songs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerProvider>();

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8E24AA)));
    }

    if (_localSongs.isEmpty) {
      return const Center(
          child: Text("Kitaplık boş. Arama sekmesinden müzik indirebilirsiniz.",
              style: TextStyle(color: Color(0xFFB3B3B3))));
    }

    return Column(
      children: [
        // ── Arama Çubuğu ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Şarkılarda ara...',
              hintStyle: const TextStyle(color: Color(0xFF777777)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF777777)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF777777)),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // ── Kontrol Butonları ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _searchQuery.isEmpty
                    ? '${_localSongs.length} şarkı'
                    : '${_localSongs.where((s) => s.title.toLowerCase().contains(_searchQuery)).length} sonuç',
                style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
              ),
              Row(children: [
                IconButton(
                  icon: Icon(
                    provider.libraryLoopMode == LoopMode.all
                        ? Icons.repeat
                        : (provider.libraryLoopMode == LoopMode.one
                            ? Icons.repeat_one
                            : Icons.repeat),
                    color: provider.libraryLoopMode == LoopMode.off
                        ? const Color(0xFFB3B3B3)
                        : const Color(0xFF8E24AA),
                  ),
                  onPressed: () => provider.toggleLoopMode("Kitaplık"),
                ),
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: provider.libraryIsShuffle
                        ? const Color(0xFF8E24AA)
                        : const Color(0xFFB3B3B3),
                  ),
                  onPressed: () => provider.toggleShuffle("Kitaplık"),
                ),
              ]),
            ],
          ),
        ),
        // ── Şarkı Listesi ─────────────────────────────────────────────────────
        Expanded(
          child: Builder(builder: (context) {
            // Filtrelenmiş liste (arama aktifse uygula)
            final filteredSongs = _searchQuery.isEmpty
                ? _localSongs
                : _localSongs
                    .where((s) =>
                        s.title.toLowerCase().contains(_searchQuery) ||
                        s.author.toLowerCase().contains(_searchQuery))
                    .toList();

            if (filteredSongs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off, color: Color(0xFF555555), size: 48),
                    const SizedBox(height: 12),
                    Text(
                      '"$_searchQuery" için sonuç bulunamadı',
                      style: const TextStyle(color: Color(0xFFB3B3B3)),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _loadLocalFiles,
              color: const Color(0xFF8E24AA),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filteredSongs.length,
                itemBuilder: (context, index) {
                  final song = filteredSongs[index];
                  final isActive = provider.currentSong?.id == song.id;

                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF252525)
                          : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: isActive
                          ? Border.all(color: const Color(0xFF8E24AA), width: 1)
                          : null,
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<Uint8List?>(
                            future: ImageCacheService().getImage(song.id),
                            builder: (ctx, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return Container(
                                    width: 45,
                                    height: 45,
                                    color: const Color(0xFF2B2B2B),
                                    child: const Icon(Icons.music_note,
                                        color: Color(0xFF555555), size: 20));
                              }
                              if (snap.hasData && snap.data != null) {
                                return Image.memory(snap.data!,
                                    width: 45, height: 45, fit: BoxFit.cover);
                              }
                              return Container(
                                  width: 45,
                                  height: 45,
                                  color: const Color(0xFF1E1E1E),
                                  child: Icon(Icons.music_note,
                                      color: isActive
                                          ? const Color(0xFF8E24AA)
                                          : const Color(0xFFB3B3B3),
                                      size: 30));
                            }),
                      ),
                      title: Text(
                        song.title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        isActive ? "Oynatılıyor" : "Yerel Dosya",
                        style: TextStyle(
                            color: isActive
                                ? const Color(0xFF8E24AA)
                                : const Color(0xFFB3B3B3),
                            fontSize: 11),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon:
                            const Icon(Icons.more_vert, color: Color(0xFFB3B3B3)),
                        color: const Color(0xFF181818),
                        onSelected: (value) async {
                          if (value == 'add') {
                            final playlists =
                                await _playlistService.loadPlaylists();
                            if (playlists.isEmpty) {
                              globalSnackbarKey.currentState?.showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Önce Listeler sekmesinden liste oluşturun!")));
                              return;
                            }
                            showDialog(
                                context: context,
                                builder: (ctx) {
                                  return AlertDialog(
                                    backgroundColor: const Color(0xFF181818),
                                    title: const Text("Listeye Ekle"),
                                    content: SizedBox(
                                        width: 300,
                                        child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: playlists.keys.length,
                                            itemBuilder: (c, i) {
                                              final pName =
                                                  playlists.keys.elementAt(i);
                                              return ListTile(
                                                  title: Text(pName),
                                                  onTap: () async {
                                                    await _playlistService
                                                        .addSongToPlaylist(
                                                            pName, song.id);
                                                    Navigator.pop(ctx);
                                                    globalSnackbarKey.currentState
                                                        ?.showSnackBar(SnackBar(
                                                            content: Text(
                                                                "$pName listesine eklendi!")));
                                                  });
                                            })),
                                  );
                                });
                          } else if (value == 'delete') {
                            try {
                              File(song.id).deleteSync();
                              final image = File(song.id
                                  .replaceAll(RegExp(r'\.(mp3|m4a)$'), '.jpg'));
                              if (image.existsSync()) image.deleteSync();
                              _loadLocalFiles();
                            } catch (_) {}
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'add',
                            child: Text('Listeye Ekle'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Sil',
                                style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                      onTap: () {
                        // Şarkıya tıklanınca tüm orijinal listeyi ver ama
                        // seçilen şarkının asıl indeksini bul
                        final realIndex = _localSongs.indexOf(song);
                        provider.setPlaylist(_localSongs, realIndex,
                            source: "Kitaplık");
                      },
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}
