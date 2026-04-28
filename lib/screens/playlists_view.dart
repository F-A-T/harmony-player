import 'package:flutter/material.dart';
import '../services/playlist_service.dart';
import '../models/song.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/player_provider.dart';
import '../main.dart';
import '../services/download_service.dart';
import '../services/image_cache_service.dart';
import 'dart:typed_data';

class PlaylistsView extends StatefulWidget {
  const PlaylistsView({super.key});

  @override
  State<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends State<PlaylistsView> {
  final PlaylistService _playlistService = PlaylistService();
  final DownloadService _downloadService = DownloadService();
  Map<String, List<String>> _playlists = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _playlistService.loadPlaylists();
    setState(() {
      _playlists = data;
      _isLoading = false;
    });
  }

  void _showCreateDialog() {
    final tc = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF181818),
              title: const Text("Yeni Liste"),
              content: TextField(
                controller: tc,
                decoration: const InputDecoration(hintText: "Liste adı girin"),
                autofocus: true,
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("İptal")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954)),
                  onPressed: () async {
                    if (tc.text.isNotEmpty) {
                      await _playlistService.addSongToPlaylist(tc.text, "");
                      final data = await _playlistService.loadPlaylists();
                      data[tc.text]?.remove("");
                      await _playlistService.savePlaylists(data);
                      Navigator.pop(ctx);
                      _loadData();
                    }
                  },
                  child: const Text("Kaydet",
                      style: TextStyle(color: Colors.white)),
                )
              ],
            ));
  }

  void _showAddSongsDialog(String playlistName, List<String> currentPaths,
      Function reloadParentModal) async {
    final localFiles = await _downloadService.getLocalAudioFiles();
    Set<String> selectedPaths = {};
    bool allSelected = false;

    if (!mounted) return;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF181818),
        builder: (ctx) {
          return StatefulBuilder(builder: (c, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Şarkı Ekle",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                if (allSelected) {
                                  selectedPaths.clear();
                                } else {
                                  for (var file in localFiles) {
                                    if (!currentPaths.contains(file.path)) {
                                      selectedPaths.add(file.path);
                                    }
                                  }
                                }
                                allSelected = !allSelected;
                              });
                            },
                            child: Text(
                                allSelected ? "Seçimi Kaldır" : "Tümünü Seç",
                                style:
                                    const TextStyle(color: Color(0xFF1DB954))),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1DB954)),
                            onPressed: () async {
                              if (selectedPaths.isNotEmpty) {
                                final pData =
                                    await _playlistService.loadPlaylists();
                                final list = pData[playlistName] ?? [];
                                for (var path in selectedPaths) {
                                  if (!list.contains(path)) list.add(path);
                                }
                                pData[playlistName] = list;
                                await _playlistService.savePlaylists(pData);
                                reloadParentModal();
                                _loadData();
                              }
                              Navigator.pop(ctx);
                            },
                            child: Text("Kaydet (${selectedPaths.length})",
                                style: const TextStyle(color: Colors.white)),
                          )
                        ],
                      )
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: localFiles.length,
                      itemBuilder: (builderCtx, idx) {
                        final file = localFiles[idx];
                        final name = p.basenameWithoutExtension(file.path);
                        final isAlreadyIn = currentPaths.contains(file.path);
                        final isSelected = selectedPaths.contains(file.path);

                        return CheckboxListTile(
                          activeColor: const Color(0xFF1DB954),
                          checkColor: Colors.white,
                          title: Text(name,
                              style: TextStyle(
                                  color: isAlreadyIn
                                      ? Colors.grey
                                      : Colors.white)),
                          subtitle: isAlreadyIn
                              ? const Text("Zaten listede",
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey))
                              : null,
                          value: isAlreadyIn ? true : isSelected,
                          onChanged: isAlreadyIn
                              ? null
                              : (val) {
                                  setSheetState(() {
                                    if (val == true) {
                                      selectedPaths.add(file.path);
                                    } else {
                                      selectedPaths.remove(file.path);
                                    }
                                  });
                                },
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          });
        });
  }

  void _showPlaylistDetail(String playlistName, List<String> paths) {
    bool isEditMode = false;
    Set<int> selectedIndexes = {};

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setModalState) {
            void refreshInternal() async {
              final pData = await _playlistService.loadPlaylists();
              paths.clear();
              paths.addAll(pData[playlistName] ?? []);
              setModalState(() {});
            }

            List<Song> songs =
                paths.where((pPath) => File(pPath).existsSync()).map((path) {
              final name = p.basenameWithoutExtension(path);
              return Song.fromLocal(path, name, "");
            }).toList();

            return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                    color: Color(0xFF121212),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20))),
                padding: const EdgeInsets.only(top: 10, left: 20, right: 20),
                child: Column(children: [
                  // Top drag indicator
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  // Header (Playlist Cover + Title + Stats)
                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF1DB954), Color(0xFF116B31)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black45,
                                blurRadius: 10,
                                offset: Offset(0, 5))
                          ],
                        ),
                        child: const Center(
                            child: Icon(Icons.music_note,
                                color: Colors.white, size: 50)),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(playlistName,
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 5),
                            Text("${songs.length} Şarkı",
                                style: const TextStyle(
                                    color: Color(0xFFB3B3B3), fontSize: 13)),
                          ]))
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Buttons Row
                  Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        // Play & Shuffle
                        Row(children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1DB954),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20))),
                            icon: const Icon(Icons.play_arrow, size: 20),
                            label: const Text("Oynat",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              if (songs.isNotEmpty) {
                                Provider.of<PlayerProvider>(context,
                                        listen: false)
                                    .setPlaylist(songs, 0,
                                        source: "Liste: $playlistName");
                              }
                            },
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.shuffle),
                            color: Provider.of<PlayerProvider>(context)
                                    .playlistIsShuffle
                                ? const Color(0xFF1DB954)
                                : const Color(0xFFB3B3B3),
                            onPressed: () => Provider.of<PlayerProvider>(
                                    context,
                                    listen: false)
                                .toggleShuffle("Liste"),
                          ),
                          IconButton(
                            icon: Icon(
                              Provider.of<PlayerProvider>(context)
                                          .playlistLoopMode ==
                                      LoopMode.all
                                  ? Icons.repeat
                                  : Provider.of<PlayerProvider>(context)
                                              .playlistLoopMode ==
                                          LoopMode.one
                                      ? Icons.repeat_one
                                      : Icons.repeat,
                            ),
                            color: Provider.of<PlayerProvider>(context)
                                        .playlistLoopMode ==
                                    LoopMode.off
                                ? const Color(0xFFB3B3B3)
                                : const Color(0xFF1DB954),
                            onPressed: () => Provider.of<PlayerProvider>(
                                    context,
                                    listen: false)
                                .toggleLoopMode("Liste"),
                          ),
                        ]),
                        // Action Buttons
                        Row(children: [
                          if (!isEditMode)
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.white),
                              tooltip: "Şarkı Ekle",
                              onPressed: () => _showAddSongsDialog(
                                  playlistName, paths, refreshInternal),
                            ),
                          if (isEditMode)
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              tooltip: "Seçilileri Sil",
                              onPressed: () async {
                                final sortedIndexes = selectedIndexes.toList()
                                  ..sort((a, b) => b.compareTo(a));
                                for (int idx in sortedIndexes) {
                                  paths.removeAt(idx);
                                }
                                final dict =
                                    await _playlistService.loadPlaylists();
                                dict[playlistName] = paths;
                                await _playlistService.savePlaylists(dict);
                                setModalState(() {
                                  isEditMode = false;
                                  selectedIndexes.clear();
                                });
                                _loadData(); // Sync parent view
                              },
                            ),
                          IconButton(
                            icon: Icon(isEditMode ? Icons.done : Icons.edit,
                                color: isEditMode
                                    ? const Color(0xFF1DB954)
                                    : const Color(0xFFB3B3B3)),
                            tooltip: "Düzenle Modu",
                            onPressed: () {
                              setModalState(() {
                                isEditMode = !isEditMode;
                                selectedIndexes.clear();
                              });
                            },
                          ),
                          if (!isEditMode)
                            IconButton(
                              icon: const Icon(Icons.delete_forever,
                                  color: Colors.red),
                              tooltip: "Listeyi Komple Sil",
                              onPressed: () async {
                                await _playlistService
                                    .deletePlaylist(playlistName);
                                Navigator.pop(ctx);
                                _loadData();
                              },
                            )
                        ])
                      ]),
                  const Divider(color: Colors.white24, height: 30),
                  Expanded(
                      child: songs.isEmpty
                          ? const Center(
                              child: Text("Bu liste boş.",
                                  style: TextStyle(color: Color(0xFFB3B3B3))))
                          : ListView.builder(
                              itemCount: songs.length,
                              itemBuilder: (c, i) {
                                final song = songs[i];
                                final isPlaying =
                                    Provider.of<PlayerProvider>(context)
                                                .currentSong
                                                ?.id ==
                                            song.id &&
                                        Provider.of<PlayerProvider>(context)
                                                .currentSource ==
                                            "Liste: $playlistName";
                                return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isPlaying
                                          ? const Color(0xFF1DB954)
                                              .withOpacity(0.2)
                                          : (isEditMode &&
                                                  selectedIndexes.contains(i)
                                              ? const Color(0xFF1DB954)
                                                  .withOpacity(0.1)
                                              : Colors.transparent),
                                      borderRadius: BorderRadius.circular(8),
                                      border: isPlaying
                                          ? Border.all(
                                              color: const Color(0xFF1DB954),
                                              width: 1)
                                          : null,
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 4),
                                      leading: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                final tc =
                                                    TextEditingController(
                                                        text:
                                                            (i + 1).toString());
                                                showDialog(
                                                    context: context,
                                                    builder:
                                                        (ctx) => AlertDialog(
                                                              backgroundColor:
                                                                  const Color(
                                                                      0xFF181818),
                                                              title: const Text(
                                                                  "Hedef Sıra (Taşı)"),
                                                              content:
                                                                  TextField(
                                                                controller: tc,
                                                                keyboardType:
                                                                    TextInputType
                                                                        .number,
                                                                decoration:
                                                                    InputDecoration(
                                                                        hintText:
                                                                            "1 ile ${songs.length} arası"),
                                                                autofocus: true,
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx),
                                                                    child: const Text(
                                                                        "İptal")),
                                                                ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                      backgroundColor:
                                                                          const Color(
                                                                              0xFF1DB954)),
                                                                  onPressed:
                                                                      () async {
                                                                    int?
                                                                        newIndex =
                                                                        int.tryParse(
                                                                            tc.text);
                                                                    if (newIndex != null &&
                                                                        newIndex >=
                                                                            1 &&
                                                                        newIndex <=
                                                                            songs.length) {
                                                                      newIndex -=
                                                                          1;
                                                                      final temp =
                                                                          paths.removeAt(
                                                                              i);
                                                                      paths.insert(
                                                                          newIndex,
                                                                          temp);
                                                                      final dict =
                                                                          await _playlistService
                                                                              .loadPlaylists();
                                                                      dict[playlistName] =
                                                                          paths;
                                                                      await _playlistService
                                                                          .savePlaylists(
                                                                              dict);
                                                                      _loadData();
                                                                      setModalState(
                                                                          () {});
                                                                      Navigator
                                                                          .pop(
                                                                              ctx);
                                                                    }
                                                                  },
                                                                  child: const Text(
                                                                      "Taşı",
                                                                      style: TextStyle(
                                                                          color:
                                                                              Colors.white)),
                                                                )
                                                              ],
                                                            ));
                                              },
                                              child: Container(
                                                width: 25,
                                                alignment: Alignment.center,
                                                child: Text("${i + 1}",
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFFB3B3B3),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            isEditMode
                                                ? Checkbox(
                                                    value: selectedIndexes
                                                        .contains(i),
                                                    activeColor:
                                                        const Color(0xFF1DB954),
                                                    onChanged: (val) {
                                                      setModalState(() {
                                                        if (val == true)
                                                          selectedIndexes
                                                              .add(i);
                                                        else
                                                          selectedIndexes
                                                              .remove(i);
                                                      });
                                                    })
                                                : ClipRRect(
                                                    borderRadius: BorderRadius
                                                        .circular(4),
                                                    child: FutureBuilder<
                                                            Uint8List?>(
                                                        future:
                                                            ImageCacheService()
                                                                .getImage(
                                                                    song.id),
                                                        builder: (ctx, snap) {
                                                          if (snap.connectionState ==
                                                              ConnectionState
                                                                  .waiting)
                                                            return Container(
                                                                width: 45,
                                                                height: 45,
                                                                color: const Color(
                                                                    0xFF2B2B2B),
                                                                child: const Icon(
                                                                    Icons
                                                                        .music_note,
                                                                    color: Color(
                                                                        0xFF555555),
                                                                    size: 20));
                                                          if (snap.hasData &&
                                                              snap.data != null)
                                                            return Image.memory(
                                                                snap.data!,
                                                                width: 45,
                                                                height: 45,
                                                                fit: BoxFit
                                                                    .cover);
                                                          return Container(
                                                              width: 45,
                                                              height: 45,
                                                              color: const Color(
                                                                  0xFF1E1E1E),
                                                              child: const Icon(
                                                                  Icons
                                                                      .music_note,
                                                                  color: Color(
                                                                      0xFFB3B3B3),
                                                                  size: 24));
                                                        })),
                                          ]),
                                      title: Text(song.title,
                                          maxLines: 1,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: isPlaying
                                                  ? const Color(0xFF1DB954)
                                                  : Colors.white)),
                                      trailing: isEditMode
                                          ? null
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.keyboard_arrow_up,
                                                      color: Color(0xFFB3B3B3)),
                                                  onPressed: i > 0
                                                      ? () async {
                                                          final temp = paths[i];
                                                          paths[i] =
                                                              paths[i - 1];
                                                          paths[i - 1] = temp;
                                                          final dict =
                                                              await _playlistService
                                                                  .loadPlaylists();
                                                          dict[playlistName] =
                                                              paths;
                                                          await _playlistService
                                                              .savePlaylists(
                                                                  dict);
                                                          _loadData();
                                                          setModalState(() {});
                                                        }
                                                      : null,
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.keyboard_arrow_down,
                                                      color: Color(0xFFB3B3B3)),
                                                  onPressed: i <
                                                          songs.length - 1
                                                      ? () async {
                                                          final temp = paths[i];
                                                          paths[i] =
                                                              paths[i + 1];
                                                          paths[i + 1] = temp;
                                                          final dict =
                                                              await _playlistService
                                                                  .loadPlaylists();
                                                          dict[playlistName] =
                                                              paths;
                                                          await _playlistService
                                                              .savePlaylists(
                                                                  dict);
                                                          _loadData();
                                                          setModalState(() {});
                                                        }
                                                      : null,
                                                ),
                                              ],
                                            ),
                                      onTap: () {
                                        if (isEditMode) {
                                          setModalState(() {
                                            if (selectedIndexes.contains(i))
                                              selectedIndexes.remove(i);
                                            else
                                              selectedIndexes.add(i);
                                          });
                                        } else {
                                          Provider.of<PlayerProvider>(context,
                                                  listen: false)
                                              .setPlaylist(songs, i,
                                                  source:
                                                      "Liste: $playlistName");
                                        }
                                      },
                                    ));
                              }))
                ]));
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1DB954)));

    return Scaffold(
      body: _playlists.isEmpty
          ? const Center(
              child: Text("Henüz hiç liste oluşturmadınız.",
                  style: TextStyle(color: Color(0xFFB3B3B3))))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF1DB954),
              child: ListView.builder(
                  padding: const EdgeInsets.only(top: 10, bottom: 80),
                  itemCount: _playlists.length,
                  itemBuilder: (context, index) {
                    String pName = _playlists.keys.elementAt(index);
                    List<String> paths = _playlists[pName]!;
                    return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.playlist_play,
                              color: Color(0xFF1DB954), size: 30),
                          title: Text(pName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${paths.length} Şarkı",
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFB3B3B3))),
                          onTap: () => _showPlaylistDetail(pName, paths),
                        ));
                  })),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50),
        child: FloatingActionButton(
          onPressed: _showCreateDialog,
          backgroundColor: const Color(0xFF1DB954),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
