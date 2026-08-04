import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;

void main() async {
  final yt = YoutubeExplode();
  try {
    print('Searching...');
    final searchResults = await yt.search.search('top hits 2026 musique officielle');
    final videos = searchResults.whereType<Video>().toList();
    final firstVideo = videos.first;
    print('Found video: \${firstVideo.id.value}');

    final manifest = await yt.videos.streamsClient.getManifest(firstVideo.id.value);
    final audioMp4Streams = manifest.audioOnly.where((s) => s.container == StreamContainer.mp4);
    
    StreamInfo streamInfo;
    if (audioMp4Streams.isNotEmpty) {
      streamInfo = audioMp4Streams.withHighestBitrate();
    } else {
      streamInfo = manifest.audioOnly.withHighestBitrate();
    }
    
    final url = streamInfo.url.toString();
    print('Stream URL: \$url');

    print('Testing HTTP GET on stream URL without headers...');
    final response = await http.get(Uri.parse(url), headers: {
      'Range': 'bytes=0-1000',
    });
    
    print('HTTP Status: \${response.statusCode}');
    if (response.statusCode == 403) {
      print('HTTP 403 FORBIDDEN. Testing with iOS YouTube App User-Agent...');
      final response2 = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'com.google.ios.youtube/19.23.3 (iPhone14,5; U; CPU iOS 17_5_1 like Mac OS X;)',
        'Range': 'bytes=0-1000',
      });
      print('HTTP Status (iOS UA): \${response2.statusCode}');
      
      print('Testing with Android YouTube App User-Agent...');
      final response3 = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip',
        'Range': 'bytes=0-1000',
      });
      print('HTTP Status (Android UA): \${response3.statusCode}');
    }

  } catch (e) {
    print('Error: \$e');
  } finally {
    yt.close();
  }
}
