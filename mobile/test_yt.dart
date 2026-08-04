import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    print('Searching...');
    final searchResults = await yt.search.search('top hits 2026 musique officielle');
    final videos = searchResults.whereType<Video>().toList();
    if (videos.isEmpty) {
      print('No videos found');
      return;
    }
    final firstVideo = videos.first;
    print('Found video: \${firstVideo.title} (ID: \${firstVideo.id.value})');

    print('Getting manifest...');
    final manifest = await yt.videos.streamsClient.getManifest(firstVideo.id.value);
    
    print('Audio streams: \${manifest.audioOnly.length}');
    if (manifest.audioOnly.isNotEmpty) {
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      print('Stream URL: \${streamInfo.url}');
    } else {
      print('No audio streams found!');
    }
  } catch (e) {
    print('Error: \$e');
  } finally {
    yt.close();
  }
}
