import 'dart:io';

void main() {
  final file = File('lib/core/constants/artists_data.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll(r'$', r'\$');
  file.writeAsStringSync(content);
  print('Fixed dollar signs!');
}
