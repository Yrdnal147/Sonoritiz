import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:io';
import 'package:dio/dio.dart';

void main() {
  test('Youtube Explode Download', () async {
    final yt = YoutubeExplode();
    final dio = Dio();
    final trackId = 'kJQP7kiw5Fk'; // Despacito

    try {
      print('Fetching manifest...');
      final manifest = await yt.videos.streamsClient.getManifest(trackId).timeout(const Duration(seconds: 15));
      print('Manifest fetched!');
      String audioUrl = '';
      print('Downloading via YoutubeExplode...');
      var stream;
      if (manifest.audioOnly.isNotEmpty) {
        stream = yt.videos.streamsClient.get(manifest.audioOnly.withHighestBitrate());
      } else {
        stream = yt.videos.streamsClient.get(manifest.muxed.sortByVideoQuality().last);
      }
      
      final file = File('test_download.mp4');
      final fileStream = file.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();
      
      print('Download success! File size: ${await file.length()}');
      expect(await file.length() > 0, true);
    } catch (e) {
      print('Error: $e');
      fail('Exception: $e');
    } finally {
      yt.close();
    }
  });
}
