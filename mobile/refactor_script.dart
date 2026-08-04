import 'dart:io';

void main() {
  final file = File('lib/features/player/presentation/screens/fullscreen_player_screen.dart');
  var content = file.readAsStringSync();

  if (!content.contains("import 'dart:math' as math;")) {
    content = content.replaceFirst(
      "import 'package:flutter/material.dart';",
      "import 'package:flutter/material.dart';\nimport 'dart:math' as math;\nimport '../../../core/utils/responsive_utils.dart';"
    );
  }

  final String targetStart = """                        return Column(
                          children: [
                            // --- APP BAR (Top) ---""";
  
  final String newStart = """
                        final isDesktop = ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isTablet(context);
                        final double coverSize = isDesktop 
                            ? math.min(screenWidth / 2 - 64, screenHeight * 0.6) 
                            : screenWidth - 32;

                        final appBar = """;

  content = content.replaceFirst(targetStart, newStart + '// --- APP BAR (Top) ---');

  // Replace screenWidth - 32 with coverSize
  content = content.replaceAll('screenWidth - 32', 'coverSize');
  content = content.replaceAll('screenWidth - 48', '(coverSize - 16)');

  content = content.replaceFirst(
    """                            const SizedBox(height: 16),

                            // --- POCHETTE OU VIDÉO ---""",
    ';\n\n                        final coverArt = '
  );

  content = content.replaceFirst(
    """                            const SizedBox(height: 24),

                            // --- TITRE & ARTISTE ---""",
    ';\n\n                        final info = '
  );

  content = content.replaceFirst(
    """                            const SizedBox(height: 24),

                            // --- SLIDER & TEMPS ---""",
    ';\n\n                        final sliderWidget = '
  );

  content = content.replaceFirst(
    """                            const Spacer(),

                            // --- CONTRÔLES PRINCIPAUX ---""",
    ';\n\n                        final mainControls = '
  );

  content = content.replaceFirst(
    """                            const Spacer(),

                            // --- BOUTONS SECONDAIRES (Paroles, Bascule Vidéo, File d'attente) ---""",
    ';\n\n                        final sideActions = '
  );

  final String targetEnd = """                            const SizedBox(height: 24),
                          ],
                        );""";
  
  final String layoutCode = """
                        if (isDesktop) {
                          return Column(
                            children: [
                              appBar,
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Center(child: coverArt),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 48.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            info,
                                            const SizedBox(height: 48),
                                            sliderWidget,
                                            const SizedBox(height: 32),
                                            mainControls,
                                            const SizedBox(height: 48),
                                            sideActions,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            appBar,
                            const SizedBox(height: 16),
                            coverArt,
                            const SizedBox(height: 24),
                            info,
                            const SizedBox(height: 24),
                            sliderWidget,
                            const Spacer(),
                            mainControls,
                            const Spacer(),
                            sideActions,
                            const SizedBox(height: 24),
                          ],
                        );""";

  content = content.replaceFirst(targetEnd, ';\n\n' + layoutCode);

  file.writeAsStringSync(content);
}
