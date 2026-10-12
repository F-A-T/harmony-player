import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/queue_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'webview_scraper.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => SearchViewState();
}

class SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();

  List<Song> _searchResults = [];
  bool _isSearching = false;

  void performSearchFromOutside(String query) {
    _searchController.text = query;
    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus(); // Unfocus keyboard

    // Check for Spotify Links
    if (query.contains("spotify.com/playlist/")) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Spotify doğrudan indirmeyi kapattı! Lütfen 'Exportify' sitesi ile listenizi CSV/JSON olarak indirip alttaki 'Dosyadan İçe Aktar' tuşuyla yükleyin.",
              style: TextStyle(fontSize: 12)),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.red));
      return;
    }

    // Check for Youtube Links
    if (query.contains("youtube.com/playlist?list=") ||
        query.contains("music.youtube.com/playlist?list=")) {
      setState(() => _isSearching = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("YouTube listesi çekiliyor... (Lütfen bekleyin)")));
      final provider = context.read<PlayerProvider>();
      final vids = await provider.youtubeService.getPlaylistVideos(query);
      if (!mounted) return;
      setState(() => _isSearching = false);
      if (vids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Liste gizli olabilir veya bulunamadı!")));
        return;
      }
      List<QueueItem> items = vids
          .map(
              (v) => QueueItem(title: v.title, artist: v.author, videoId: v.id))
          .toList();
      context.read<QueueProvider>().addMultipleToQueue(items);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text("${items.length} adet Youtube şarkısı kuyruğa eklendi!")));
      _showQueueDialog();
      return;
    }

    setState(() => _isSearching = true);
    final provider = context.read<PlayerProvider>();
    final results = await provider.youtubeService.searchSongs(query);

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _downloadSong(Song song) {
    context.read<QueueProvider>().addToQueue(song.title, song.author, song.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text("${song.title} kuyruğa eklendi."),
          backgroundColor: const Color(0xFF8E24AA),
          duration: const Duration(seconds: 1)),
    );
  }

  void _showLinkInputDialog(String platform) {
    final tc = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF181818),
              title: Text("$platform Listesi İndir"),
              content: TextField(
                controller: tc,
                decoration: InputDecoration(
                    hintText: "$platform liste bağlantısını buraya yapıştırın"),
                autofocus: true,
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("İptal")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8E24AA)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    performSearchFromOutside(tc.text);
                  },
                  child: const Text("Kuyruğa Ekle",
                      style: TextStyle(color: Colors.white)),
                )
              ],
            ));
  }

  void _importFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String contents = await file.readAsString();
        String extension = result.files.single.extension?.toLowerCase() ?? "";

        List<QueueItem> itemsToQueue = [];

        if (extension == 'json') {
          var jsonData = jsonDecode(contents);
          List<dynamic> list = [];

          if (jsonData is List) {
            list = jsonData;
          } else if (jsonData is Map) {
            for (var value in jsonData.values) {
              if (value is List) {
                list = value;
                break;
              }
            }
            if (list.isEmpty) list = [jsonData];
          }

          for (var item in list) {
            if (item is Map) {
              String title = "";
              String artist = "";

              // nested google api snippet check (Export Vercel vs.)
              if (item.containsKey("snippet") && item["snippet"] is Map) {
                title = item["snippet"]["title"] ?? "";
                artist = item["snippet"]["videoOwnerChannelTitle"] ??
                    item["snippet"]["channelTitle"] ??
                    "";
              }

              if (title.isEmpty) {
                title = item['trackName'] ??
                    item['title'] ??
                    item['name'] ??
                    item['track'] ??
                    item['videoTitle'] ??
                    "";
              }
              if (artist.isEmpty) {
                artist = item['artistName'] ??
                    item['artist'] ??
                    item['author'] ??
                    item['channelTitle'] ??
                    "";
              }

              if (title.isNotEmpty &&
                  title != "Private video" &&
                  title != "Deleted video") {
                itemsToQueue.add(QueueItem(title: title, artist: artist));
              }
            }
          }
        } else if (extension == 'csv') {
          List<String> lines = contents.split('\n');
          if (lines.isNotEmpty) {
            String headerLine = lines[0].toLowerCase();
            List<String> headers = headerLine.split(',');
            int titleIdx = headers.indexWhere(
                (h) => h.contains('track name') || h == 'name' || h == 'title');
            int artistIdx = headers
                .indexWhere((h) => h.contains('artist name') || h == 'artist');

            if (titleIdx == -1) titleIdx = 1;
            if (artistIdx == -1) artistIdx = 2;

            for (int i = 1; i < lines.length; i++) {
              String line = lines[i].trim();
              if (line.isEmpty) continue;

              List<String> row = [];
              bool inQuotes = false;
              String val = "";
              for (int j = 0; j < line.length; j++) {
                if (line[j] == '"') {
                  inQuotes = !inQuotes;
                } else if (line[j] == ',' && !inQuotes) {
                  row.add(val.replaceAll('"', '').trim());
                  val = "";
                } else {
                  val += line[j];
                }
              }
              row.add(val.replaceAll('"', '').trim());

              if (row.length > titleIdx) {
                String title = row[titleIdx];
                String artist = row.length > artistIdx ? row[artistIdx] : "";
                if (title.isNotEmpty)
                  itemsToQueue.add(QueueItem(title: title, artist: artist));
              }
            }
          }
        } else {
          List<String> lines = contents.split('\n');
          for (var line in lines) {
            if (line.trim().isEmpty) continue;
            itemsToQueue.add(QueueItem(title: line.trim(), artist: ""));
          }
        }

        if (itemsToQueue.isNotEmpty && mounted) {
          context.read<QueueProvider>().addMultipleToQueue(itemsToQueue);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "${itemsToQueue.length} şarkı dosyadan kuyruğa aktarıldı!"),
              backgroundColor: const Color(0xFF8E24AA)));
          _showQueueDialog();
        } else {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    "Dosyanın içerisinden algılanabilir müzik bulunamadı."),
                backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Dosya okuma hatası: $e")));
    }
  }

  void _showQueueDialog() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF121212),
        builder: (ctx) {
          return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.only(top: 10),
              child: Column(children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)))),
                Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("İndirme Kuyruğu",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                              icon: const Icon(Icons.cancel_outlined,
                                  color: Colors.redAccent),
                              label: const Text("Tümünü İptal Et",
                                  style: TextStyle(color: Colors.redAccent)),
                              onPressed: () {
                                context.read<QueueProvider>().clearQueue();
                                Navigator.pop(context);
                              })
                        ])),
                Expanded(child:
                    Consumer<QueueProvider>(builder: (context, qProvider, _) {
                  final queue = qProvider.queue;
                  if (queue.isEmpty) {
                    return const Center(
                        child: Text("Kuyruk boş.",
                            style: TextStyle(color: Colors.grey)));
                  }
                  return ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (cc, i) {
                        final item = queue[i];
                        IconData icon;
                        Color c;
                        String localStatusLabel = "";

                        if (item.status == "waiting") {
                          icon = Icons.timer;
                          c = Colors.grey;
                          localStatusLabel = "Sırada Bekliyor";
                        } else if (item.status == "downloading") {
                          icon = Icons.downloading;
                          c = Colors.blue;
                          localStatusLabel = "İndiriliyor...";
                        } else if (item.status == "skipped") {
                          icon = Icons.fast_forward;
                          c = Colors.orange;
                          localStatusLabel = "Zaten İndirilmiş (Atlandı)";
                        } else if (item.status == "completed") {
                          icon = Icons.check_circle;
                          c = const Color(0xFF8E24AA);
                          localStatusLabel = "Başarılı";
                        } else {
                          icon = Icons.error;
                          c = Colors.red;
                          localStatusLabel = "Hata Oluştu";
                        }

                        return ListTile(
                          leading: Icon(icon, color: c),
                          title: Text(item.title,
                              maxLines: 1,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              "${item.artist ?? "Bilinmiyor"} - $localStatusLabel",
                              style: TextStyle(color: c, fontSize: 12)),
                        );
                      });
                }))
              ]));
        });
  }

  Widget _buildMainActionCard(IconData icon, String title, String subtitle,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerProvider>();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
                top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
            child: Column(
              children: [
                _buildMainActionCard(
                    Icons.video_library,
                    "YouTube Music'te Gözat",
                    "İstediğin listeyi aç, ekrandakileri anında indir.",
                    Colors.redAccent,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WebViewScraper(
                                url: 'https://music.youtube.com')))),
                const SizedBox(height: 12),
                _buildMainActionCard(
                    Icons.import_export,
                    "Exportify ile Spotify Çek",
                    "Bağlantıya giderek Spotify listelerini cihazınıza .csv olarak indirin.",
                    const Color(0xFF8E24AA), () async {
                  final url = Uri.parse('https://exportify.net');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            "Tarayıcı açılamadı, lütfen Chrome varsayılan mıdır kontrol edin.")));
                  }
                }),
                const SizedBox(height: 12),
                _buildMainActionCard(
                    Icons.file_upload,
                    "İnen Dosyayı Cihazdan Yükle",
                    "Exportify'dan indirdiğin .csv tablosunu yükle.",
                    Colors.orangeAccent,
                    _importFromFile),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Müzik ara veya Playlist Linki yapıştır...",
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Color(0xFF8E24AA)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Color(0xFF1E1E1E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide:
                      const BorderSide(color: Color(0xFF8E24AA), width: 2),
                ),
                suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.list_alt, color: Color(0xFFB3B3B3)),
                    tooltip: "İndirme Kuyruğu",
                    onPressed: _showQueueDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF8E24AA)),
                    onPressed: () => _performSearch(_searchController.text),
                  ),
                ]),
              ),
              onSubmitted: _performSearch,
            ),
          ),
        ),
        if (_isSearching)
          const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF8E24AA))))
        else
          SliverPadding(
              padding: const EdgeInsets.only(bottom: 80),
              sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                final song = _searchResults[index];
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(song.thumbnailUrl,
                              width: 100,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.music_note,
                                  color: Color(0xFFB3B3B3),
                                  size: 40)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(song.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(song.author,
                                  style: const TextStyle(
                                      color: Color(0xFFB3B3B3), fontSize: 11),
                                  maxLines: 1),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded,
                              color: Color(0xFF8E24AA)),
                          tooltip: "Dinle (İndirmeden)",
                          onPressed: () {
                            provider
                                .setPlaylist([song], 0, source: "Online Yayın");
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_rounded,
                              color: Color(0xFF8E24AA)),
                          tooltip: "Sıraya Ekle",
                          onPressed: () => _downloadSong(song),
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: _searchResults.length)))
      ],
    );
  }
}
