import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeAudioSource extends StreamAudioSource {
  final StreamInfo streamInfo;
  final String contentType;

  YoutubeAudioSource(this.streamInfo)
      : contentType = streamInfo.container == StreamContainer.mp4 ? 'audio/mp4' : 'audio/webm';

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    
    // On n'envoie AUCUN User-Agent, Referer, ou Origin. 
    // Juste la plage d'octets.
    final request = http.Request('GET', streamInfo.url);
    request.headers['Range'] = 'bytes=' + start.toString() + '-' + (end?.toString() ?? '');

    final response = await http.Client().send(request);

    if (response.statusCode != 200 && response.statusCode != 206) {
      final body = await response.stream.bytesToString();
      throw Exception('Erreur HTTP ' + response.statusCode.toString() + ' Body: ' + body);
    }

    final contentLength = response.contentLength ?? (streamInfo.size.totalBytes - start);

    return StreamAudioResponse(
      sourceLength: streamInfo.size.totalBytes,
      contentLength: contentLength,
      offset: start,
      stream: response.stream,
      contentType: contentType,
    );
  }
}
