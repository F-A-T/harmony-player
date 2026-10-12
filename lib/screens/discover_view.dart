import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/download_service.dart';
import '../services/image_cache_service.dart';

class DiscoverView extends StatefulWidget {
  final Function(String) onSearchQuery;

  const DiscoverView({super.key, required this.onSearchQuery});

  @override
  State<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends State<DiscoverView> {
  final DownloadService _downloadService = DownloadService();
  List<Song> _recentLocalSongs = [];
  bool _isLoadingLocal = true;

  @override
  void initState() {
    super.initState();
    _loadLocalLibraryPreview();
  }

  Future<void> _loadLocalLibraryPreview() async {
    try {
      final files = await _downloadService.getLocalAudioFiles();
      final songs = files.map((file) {
        final name = p.basenameWithoutExtension(file.path);
        final thumbPath = file.path.replaceAll(RegExp(r'\.(mp3|m4a)$'), '.jpg');
        return Song.fromLocal(file.path, name, thumbPath);
      }).toList();

      if (mounted) {
        setState(() {
          _recentLocalSongs = songs;
          _isLoadingLocal = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLocal = false);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "Günaydın ☀️";
    } else if (hour >= 12 && hour < 18) {
      return "İyi Günler 🌤️";
    } else if (hour >= 18 && hour < 23) {
      return "İyi Akşamlar 🌙";
    } else {
      return "İyi Geceler 🌌";
    }
  }

  void _showSleepTimerDialog(BuildContext context, PlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final hasTimer = provider.hasActiveSleepTimer;
            final remaining = provider.remainingSleepTime;
            final remainingText = remaining != null
                ? "${remaining.inMinutes} dakika ${remaining.inSeconds % 60} saniye"
                : "";

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.bedtime_rounded, color: Color(0xFFFF9800), size: 24),
                        SizedBox(width: 8),
                        Text(
                          "Uyku Zamanlayıcısı",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (hasTimer)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          "Kalan süre: $remainingText",
                          style: const TextStyle(
                            color: Color(0xFFFF9800),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const Text(
                        "Müziğin belirli bir süre sonra otomatik durmasını sağla.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildTimerOption(ctx, provider, "15 Dakika", 15),
                        _buildTimerOption(ctx, provider, "30 Dakika", 30),
                        _buildTimerOption(ctx, provider, "45 Dakika", 45),
                        _buildTimerOption(ctx, provider, "60 Dakika", 60),
                      ],
                    ),
                    if (hasTimer) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text("Zamanlayıcıyı İptal Et"),
                        onPressed: () {
                          provider.cancelSleepTimer();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Uyku zamanlayıcısı iptal edildi."),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimerOption(
      BuildContext context, PlayerProvider provider, String label, int minutes) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF282832),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      onPressed: () {
        provider.startSleepTimer(Duration(minutes: minutes));
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Müzik $minutes dakika sonra durdurulacak 🌙"),
            backgroundColor: const Color(0xFF8E24AA),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerProvider>();
    final int dayOfWeek = DateTime.now().weekday;
    final List<Map<String, String>> dailyMixes = [
      {"name": "Pazartesi Enerjisi", "desc": "Haftaya dinamik ve motive başla"},
      {"name": "Akustik Salı", "desc": "Sakin ve dinlendirici teller"},
      {"name": "Çarşamba Pop Hit", "desc": "Hafta ortası en popüler ritimler"},
      {"name": "Perşembe Nostalji", "desc": "Zamansız ve unutulmaz klasikler"},
      {"name": "Cuma Parti Modu", "desc": "Hafta sonunu coşkuyla karşıla"},
      {"name": "Cumartesi Dans", "desc": "Dans pisti ve kulüp enerjisi"},
      {"name": "Pazar Chill & Kahve", "desc": "Huzurlu ve telaşsız melodiler"}
    ];
    final todayMix = dailyMixes[dayOfWeek - 1];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(bottom: 90),
      children: [
        // ─── 1. Dinamik Selamlama & Hızlı İşlem Başlığı ──────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _recentLocalSongs.isNotEmpty
                      ? "Kitaplığında ${_recentLocalSongs.length} şarkı hazır"
                      : "Bugün ne dinlemek istersin?",
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                provider.hasActiveSleepTimer
                    ? Icons.bedtime_rounded
                    : Icons.bedtime_outlined,
                color: provider.hasActiveSleepTimer
                    ? const Color(0xFFFF9800)
                    : Colors.white70,
                size: 26,
              ),
              tooltip: "Uyku Zamanlayıcısı",
              onPressed: () => _showSleepTimerDialog(context, provider),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // ─── 2. Hızlı Başlatma Kartları (Grid 2x2) ───────────────────────────
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.8,
          children: [
            _buildQuickActionCard(
              icon: Icons.shuffle_rounded,
              iconColor: const Color(0xFF8E24AA),
              title: "Kitaplığı Karıştır",
              subtitle: "${_recentLocalSongs.length} Şarkı",
              onTap: () {
                if (_recentLocalSongs.isNotEmpty) {
                  final shuffled = List<Song>.from(_recentLocalSongs)..shuffle();
                  provider.setPlaylist(shuffled, 0, source: "Kitaplık (Karışık)");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Kitaplık karışık çalınıyor 🔀"),
                      backgroundColor: Color(0xFF8E24AA),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Kitaplığınızda henüz şarkı bulunmuyor."),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            _buildQuickActionCard(
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFFFF9800),
              title: "Günün Karışımı",
              subtitle: todayMix["name"]!,
              onTap: () => widget.onSearchQuery(todayMix["name"]!),
            ),
            _buildQuickActionCard(
              icon: Icons.bedtime_rounded,
              iconColor: provider.hasActiveSleepTimer
                  ? const Color(0xFFFF9800)
                  : Colors.purpleAccent,
              title: "Uyku Modu",
              subtitle: provider.hasActiveSleepTimer ? "Aktif" : "Sayaç Ayarla",
              onTap: () => _showSleepTimerDialog(context, provider),
            ),
            _buildQuickActionCard(
              icon: Icons.search_rounded,
              iconColor: Colors.tealAccent,
              title: "Trendlerde Ara",
              subtitle: "Müzik Keşfet",
              onTap: () => widget.onSearchQuery("Trend Müzikler 2026"),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── 3. Günün Karışımı Hero Banner ──────────────────────────────────
        _buildHeroBanner(
          title: todayMix["name"]!,
          desc: todayMix["desc"]!,
          onPlay: () => widget.onSearchQuery(todayMix["name"]!),
        ),

        const SizedBox(height: 24),

        // ─── 4. Kütüphanenden Hızlı Dinle (Son İndirilenler) ──────────────────
        if (!_isLoadingLocal && _recentLocalSongs.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Kütüphanenden Hızlı Dinle",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Son Eklenenler",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 175,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentLocalSongs.take(8).length,
              itemBuilder: (context, index) {
                final song = _recentLocalSongs[index];
                return GestureDetector(
                  onTap: () {
                    provider.setPlaylist(_recentLocalSongs, index, source: "Kitaplık");
                  },
                  child: Container(
                    width: 125,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 125,
                            height: 125,
                            color: const Color(0xFF1E1E24),
                            child: Stack(
                              children: [
                                FutureBuilder<Uint8List?>(
                                  future: ImageCacheService().getImage(song.id),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data != null) {
                                      return Image.memory(
                                        snapshot.data!,
                                        width: 125,
                                        height: 125,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                    return const Center(
                                      child: Icon(
                                        Icons.music_note_rounded,
                                        color: Color(0xFF8E24AA),
                                        size: 42,
                                      ),
                                    );
                                  },
                                ),
                                Positioned(
                                  right: 6,
                                  bottom: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8E24AA),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 6,
                                        )
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          song.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ─── 5. Ruh Haline & Ortama Göre Dinle (Kategoriler) ──────────────────
        const Text(
          "Ruh Haline & Ortama Göre",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildMoodCard(
              title: "Gece Sürüşü",
              desc: "Synthwave & Lo-Fi",
              icon: Icons.nightlife_rounded,
              gradientColors: const [Color(0xFF2E1A47), Color(0xFF14142B)],
              query: "Gece Sürüşü Müzikleri",
            ),
            _buildMoodCard(
              title: "Odaklanma & Ders",
              desc: "Derin Konsantrasyon",
              icon: Icons.self_improvement_rounded,
              gradientColors: const [Color(0xFF0F3D3E), Color(0xFF122C2D)],
              query: "Focus Study Lo-Fi Chill",
            ),
            _buildMoodCard(
              title: "Antrenman & Güç",
              desc: "Maksimum Tempo",
              icon: Icons.fitness_center_rounded,
              gradientColors: const [Color(0xFF802A16), Color(0xFF381008)],
              query: "Workout Motivation Music",
            ),
            _buildMoodCard(
              title: "Akustik Kahve",
              desc: "Sakin Melodiler",
              icon: Icons.coffee_rounded,
              gradientColors: const [Color(0xFF4A3423), Color(0xFF261A11)],
              query: "Akustik Türkçe Sakin",
            ),
            _buildMoodCard(
              title: "Türkçe Pop Hit",
              desc: "En Çok Dinlenenler",
              icon: Icons.star_rounded,
              gradientColors: const [Color(0xFF5E1B50), Color(0xFF290822)],
              query: "Türkçe Pop 2026 Hit",
            ),
            _buildMoodCard(
              title: "Rock & Nostalji",
              desc: "Efsane Parçalar",
              icon: Icons.electric_bolt_rounded,
              gradientColors: const [Color(0xFF1D2D44), Color(0xFF0E1724)],
              query: "Anadolu Rock Klasikler",
            ),
          ],
        ),
      ],
    );
  }

  // ─── Hızlı Başlatma Kartı Widget'ı ─────────────────────────────────────────
  Widget _buildQuickActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero Banner Widget'ı ──────────────────────────────────────────────────
  Widget _buildHeroBanner({
    required String title,
    required String desc,
    required VoidCallback onPlay,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7B1FA2),
            Color(0xFF4A148C),
            Color(0xFF1E1E24),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "GÜNÜN LİSTESİ",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
              elevation: 4,
            ),
            onPressed: onPlay,
            child: const Icon(Icons.play_arrow_rounded, size: 28),
          ),
        ],
      ),
    );
  }

  // ─── Mood & Ortam Kartı Widget'ı ───────────────────────────────────────────
  Widget _buildMoodCard({
    required String title,
    required String desc,
    required IconData icon,
    required List<Color> gradientColors,
    required String query,
  }) {
    return InkWell(
      onTap: () => widget.onSearchQuery(query),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white70, size: 24),
                const Icon(
                  Icons.arrow_outward_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
