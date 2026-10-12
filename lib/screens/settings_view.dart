import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/queue_provider.dart';
import '../providers/player_provider.dart';
import '../services/image_cache_service.dart';
import '../services/logger_service.dart';
import '../services/download_service.dart';
import '../services/playlist_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final DownloadService _downloadService = DownloadService();
  final PlaylistService _playlistService = PlaylistService();

  int _songCount = 0;
  int _playlistCount = 0;
  double _totalSizeMB = 0.0;
  String _downloadPath = '';
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final files = await _downloadService.getLocalAudioFiles();
      int totalBytes = 0;
      for (final f in files) {
        try {
          if (f is File) {
            totalBytes += await f.length();
          }
        } catch (_) {}
      }

      final playlists = await _playlistService.loadPlaylists();
      final downloadPath = await _downloadService.getDownloadDirectory();

      if (mounted) {
        setState(() {
          _songCount = files.length;
          _playlistCount = playlists.keys.length;
          _totalSizeMB = totalBytes / (1024 * 1024);
          _downloadPath = downloadPath;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
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
                const Text(
                  "Uyku Zamanlayıcısı",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
                if (provider.hasActiveSleepTimer) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text("Zamanlayıcıyı İptal Et"),
                    onPressed: () {
                      provider.cancelSleepTimer();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Uyku zamanlayıcısı iptal edildi.")),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
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
          ),
        );
      },
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 90.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Kütüphane İstatistikleri ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Kütüphane İstatistikleri",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8E24AA),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 20),
                  tooltip: "İstatistikleri Yenile",
                  onPressed: _loadStatistics,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoadingStats)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: Color(0xFF8E24AA), strokeWidth: 2),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.music_note_rounded,
                      iconColor: const Color(0xFF8E24AA),
                      title: "Parça",
                      value: "$_songCount",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.playlist_play_rounded,
                      iconColor: const Color(0xFFFF9800),
                      title: "Liste",
                      value: "$_playlistCount",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.storage_rounded,
                      iconColor: Colors.tealAccent,
                      title: "Boyut",
                      value: "${_totalSizeMB.toStringAsFixed(1)} MB",
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // ─── 2. Oynatma & Bildirim Tercihleri ────────────────────────────
            const Text(
              "Oynatma & Deneyim",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8E24AA),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      playerProvider.hasActiveSleepTimer
                          ? Icons.bedtime_rounded
                          : Icons.bedtime_outlined,
                      color: playerProvider.hasActiveSleepTimer
                          ? const Color(0xFFFF9800)
                          : Colors.purpleAccent,
                    ),
                    title: const Text("Uyku Zamanlayıcısı",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      playerProvider.hasActiveSleepTimer
                          ? "Kalan: ${playerProvider.remainingSleepTime?.inMinutes ?? 0} dakika"
                          : "Belirlenen sürede müziği otomatik durdur.",
                      style: TextStyle(
                        fontSize: 12,
                        color: playerProvider.hasActiveSleepTimer
                            ? const Color(0xFFFF9800)
                            : Colors.grey,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () => _showSleepTimerDialog(context, playerProvider),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_rounded, color: Colors.blueAccent),
                    title: const Text("MediaStyle Bildirim Desteği",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Kilit ekranında şarkı sarma çubuğu ve renkli kapak.",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.shuffle_rounded, color: Color(0xFFFF9800)),
                    title: const Text("Akıllı Karıştırma (Shuffle)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Listedeki tüm şarkılar bitene kadar tekrar çalmaz.",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 3. Depolama & Dosya Yönetimi ────────────────────────────────
            const Text(
              "Depolama & Bakım",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8E24AA),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_rounded, color: Colors.amberAccent),
                    title: const Text("İndirilen Şarkı Konumu",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      _downloadPath.isNotEmpty ? _downloadPath : "Cihaz Depolaması / Muziklerim",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_rounded, color: Colors.orangeAccent),
                    title: const Text("Görsel Önbelleğini Temizle",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Biriken albüm kapak artıklarını silerek hafıza açar.",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      ImageCacheService().clearCache();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Albüm görsel önbelleği temizlendi!"),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                    title: const Text("İndirme Kuyruğunu Sıfırla",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Bekleyen veya takılan indirme sıralamasını sıfırlar.",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      context.read<QueueProvider>().clearQueue();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("İndirme kuyruğu sıfırlandı!"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 4. Sistem & Tanılama ────────────────────────────────────────
            const Text(
              "Sistem & Tanılama",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8E24AA),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: ListTile(
                leading: const Icon(Icons.description_rounded, color: Colors.tealAccent),
                title: const Text("Hata Kayıtları (Logs)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text("Uygulama arka plan kayıtlarını görüntüleyin.",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () async {
                  final logs = await LoggerService().readLogs();
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text("Sistem Kayıtları", style: TextStyle(color: Colors.white)),
                        content: SingleChildScrollView(
                          child: SelectableText(
                            logs.isEmpty ? "Henüz kayıtlı hata yok." : logs,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              LoggerService().clearLogs();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Loglar temizlendi!")),
                              );
                            },
                            child: const Text("Temizle", style: TextStyle(color: Colors.redAccent)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Kapat", style: TextStyle(color: Color(0xFF8E24AA))),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 36),

            // ─── 5. Hakkında ─────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E24AA).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.music_note_rounded, color: Color(0xFF8E24AA), size: 32),
                  ),
                  const SizedBox(height: 10),
                  const Text("Harmony Player",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  const Text("v2.2 (Matte Dark Edition)",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  const Text("© 2026 Harmony Player",
                      style: TextStyle(fontSize: 10, color: Colors.white30)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
