import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final videoId = 'X3Ai6osw3Mk';
  final url = 'https://pipedapi.kavin.rocks/streams/' + videoId;
  
  print('Fetching ' + url);
  final response = await http.get(Uri.parse(url));
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final audioStreams = data['audioStreams'] as List;
    
    for (var stream in audioStreams) {
      if (stream['format'] == 'M4A' || stream['mimeType'] == 'audio/mp4') {
        print('Found M4A Stream: ' + stream['url']);
        return;
      }
    }
    print('No M4A stream found.');
  } else {
    print('API Error: ' + response.statusCode.toString());
  }
}
