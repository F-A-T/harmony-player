import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/queue_provider.dart';
import '../services/image_cache_service.dart';
import '../services/logger_service.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
            padding: const EdgeInsets.only(
                top: 20.0, left: 16.0, right: 16.0, bottom: 80.0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("Sistem Hizmetleri",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1DB954))),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cleaning_services,
                          color: Colors.blueAccent),
                      title: const Text("Önbelleği Temizle",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: const Text(
                          "Arkaplanda biriken kalıntı görselleri silerek hafızayı açar.",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      onTap: () {
                        ImageCacheService().clearCache();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "Bütün önbellek artıkları temizlendi!",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.blueAccent));
                      },
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_sweep,
                          color: Colors.redAccent),
                      title: const Text("Kuyruk İptal Paneli",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: const Text(
                          "Takılan indirmeleri resetlemek için tüm kuyruğu temizler.",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      onTap: () {
                        context.read<QueueProvider>().clearQueue();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Kuyruk sıfırlandı!",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.redAccent));
                      },
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    ListTile(
                      leading: const Icon(Icons.description_rounded,
                          color: Colors.orangeAccent),
                      title: const Text("Hata Kayıtları (Logs)",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: const Text(
                          "Uygulama hatalarını ve durumlarını görüntüleyin.",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      onTap: () async {
                        final logs = await LoggerService().readLogs();
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E1E),
                              title: const Text("Sistem Kayıtları",
                                  style: TextStyle(color: Colors.white)),
                              content: SingleChildScrollView(
                                child: SelectableText(logs,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    LoggerService().clearLogs();
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text("Loglar temizlendi!")));
                                  },
                                  child: const Text("Temizle",
                                      style: TextStyle(color: Colors.redAccent)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Kapat",
                                      style: TextStyle(color: Color(0xFF1DB954))),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: const [
                    Icon(Icons.music_note, color: Color(0xFF1DB954), size: 40),
                    SizedBox(height: 10),
                    Text("Harmony Player",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("v1.0.0 Resmi Dağıtım",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    SizedBox(height: 20),
                    Text("© Copyright 2026",
                        style: TextStyle(fontSize: 10, color: Colors.white30)),
                  ],
                ),
              ),
            ])));
  }
}
