class Song {
  final String id; // YouTube Video ID or Local File Path
  final String title;
  final String author;
  final Duration? duration;
  final String thumbnailUrl; // Web URL or local path (.jpg/.webp)
  final bool isLocal;

  Song({
    required this.id,
    required this.title,
    required this.author,
    this.duration,
    required this.thumbnailUrl,
    this.isLocal = false,
  });

  factory Song.fromYouTube(dynamic ytVideo) {
    return Song(
      id: ytVideo.id.value,
      title: ytVideo.title,
      author: ytVideo.author,
      duration: ytVideo.duration,
      thumbnailUrl: ytVideo.thumbnails.highResUrl,
      isLocal: false,
    );
  }

  factory Song.fromLocal(String path, String title, String thumbPath) {
    return Song(
      id: path,
      title: title,
      author: "Yerel Dosya",
      duration: null, // Depending on if we extract it during load
      thumbnailUrl: thumbPath,
      isLocal: true,
    );
  }
}
