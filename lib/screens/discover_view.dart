import 'package:flutter/material.dart';

class DiscoverView extends StatelessWidget {
  final Function(String) onSearchQuery;

  const DiscoverView({super.key, required this.onSearchQuery});

  @override
  Widget build(BuildContext context) {
    final int dayOfWeek = DateTime.now().weekday;
    final List<String> dailyMixKeywords = [
      "Pazartesi Motive Müzik",
      "Akustik Salı",
      "Çarşamba Pop Hit",
      "Perşembe Klasik",
      "Cuma Parti Şarkıları",
      "Cumartesi Dans",
      "Pazar Chillout"
    ];
    final String todayMix = dailyMixKeywords[dayOfWeek - 1];

    return ListView(
      padding: const EdgeInsets.all(16).copyWith(bottom: 80),
      children: [
        _buildCategory("Günün Karışımı (Daily Mix)", [
          {
            "t": todayMix,
            "s": "Sana Özel Günlük",
            "i": "https://picsum.photos/300?day=$dayOfWeek"
          },
        ]),
        const SizedBox(height: 25),
        _buildCategory("Haftanın Poptrendleri", [
          {
            "t": "Türkçe Pop Müzik",
            "s": "En Yeniler",
            "i": "https://picsum.photos/300?40"
          },
          {
            "t": "Akustik Hit",
            "s": "Sakin Ritmler",
            "i": "https://picsum.photos/300?41"
          },
          {
            "t": "Global Hits",
            "s": "Dünya Trendi",
            "i": "https://picsum.photos/300?42"
          },
        ]),
        const SizedBox(height: 25),
        _buildCategory("Ruh Halinize Göre", [
          {
            "t": "Focus Mode",
            "s": "Çalışırken",
            "i": "https://picsum.photos/300?43"
          },
          {
            "t": "Gece Sürüşü",
            "s": "Yolculuk",
            "i": "https://picsum.photos/300?44"
          },
          {
            "t": "Motivasyon",
            "s": "Antrenman",
            "i": "https://picsum.photos/300?45"
          },
        ]),
      ],
    );
  }

  Widget _buildCategory(String title, List<Map<String, String>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () => onSearchQuery(item["t"]!),
                child: Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(item["i"]!,
                            width: 160, height: 160, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                      Text(item["t"]!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(item["s"]!,
                          style: const TextStyle(
                              color: Color(0xFFB3B3B3), fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
