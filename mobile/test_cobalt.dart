import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://co.wuk.sh/api/json';
  
  print('Fetching from Cobalt API...');
  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'url': 'https://www.youtube.com/watch?v=X3Ai6osw3Mk',
      'isAudioOnly': true,
      'aFormat': 'mp3'
    }),
  );
  
  if (response.statusCode == 200) {
    print('Response: ' + response.body);
  } else {
    print('API Error: ' + response.statusCode.toString() + ' ' + response.body);
  }
}
