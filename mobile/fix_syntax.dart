import 'dart:io';

void main() {
  final file = File('lib/features/player/presentation/screens/fullscreen_player_screen.dart');
  var content = file.readAsStringSync();

  // Fix import
  content = content.replaceAll(
    "import '../../../core/utils/responsive_utils.dart';",
    "import '../../../../core/utils/responsive_utils.dart';"
  );

  // Fix commas at the end of widgets that became variable declarations
  content = content.replaceAll(',\n\n;', ';\n\n');
  content = content.replaceAll(',\n;', ';\n');

  file.writeAsStringSync(content);
}
