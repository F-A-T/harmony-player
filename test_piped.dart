import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    final videoId = "dQw4w9WgXcQ"; // Never Gonna Give You Up
    print("Fetching piped streams for \$videoId");
    final res = await http.get(Uri.parse('https://pipedapi.kavin.rocks/streams/\$videoId'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final audioStreams = data['audioStreams'] as List;
      if (audioStreams.isNotEmpty) {
        // filter highest bitrate m4a
        final bestAudio = audioStreams.firstWhere((s) => s['mimeType'].contains('mp4') || s['mimeType'].contains('m4a'), orElse: () => audioStreams.first);
        print("Success! Stream URL: \${bestAudio['url']}");
      } else {
        print("No audio streams found in piped data.");
      }
    } else {
      print("Piped API failed with status \${res.statusCode}");
    }
  } catch (e) {
    print("ERROR: \$e");
  }
}
