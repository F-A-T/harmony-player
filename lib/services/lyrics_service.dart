import 'dart:convert';
import 'package:http/http.dart' as http;

class LyricsService {
  Future<String> fetchLyrics(String title) async {
    try {
      // Temizleme işlemi (Python'daki ile aynı)
      var sTitle = title
          .toLowerCase()
          .replaceAll("official", "")
          .replaceAll("video", "")
          .replaceAll("audio", "")
          .replaceAll(RegExp(r'\[.*?\]'), "")
          .replaceAll(RegExp(r'\(.*?\)'), "")
          .trim();

      final encodedQuery = Uri.encodeComponent(sTitle);
      final url = Uri.parse("https://lrclib.net/api/search?q=$encodedQuery");

      final response =
          await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty && data[0]['plainLyrics'] != null) {
          return data[0]['plainLyrics'];
        } else {
          return "Maalesef bu şarkının kayıtlı Türkçe/Yabancı sözleri kütüphanede bulunamadı.";
        }
      }
      return "Maalesef bu şarkının kayıtlı Türkçe/Yabancı sözleri kütüphanede bulunamadı.";
    } catch (e) {
      print("Söz arama hatası: $e");
      return "Sözlere bağlanırken bir iletişim hatası oluştu.";
    }
  }
}
