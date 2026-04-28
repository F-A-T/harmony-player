import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    print("Searching...");
    final searchList = await yt.search.search("Tarkan");
    if(searchList.isEmpty) { print("Search failed."); return; }
    final videoId = searchList.first.id.value;
    print("Video Id: \$videoId");
    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    print("Manifest: \${manifest.audioOnly.isNotEmpty}");
  } catch (e) {
    print("ERROR CAUGHT: \$e");
  } finally {
    yt.close();
  }
}
