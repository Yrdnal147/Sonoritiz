import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/widgets/sonoritiz_brand_logo.dart';

class SplashScreen extends StatefulWidget {
  final StorageService? storageService;
  final Duration splashDuration;
  final bool enableAudio;

  const SplashScreen({
    super.key,
    this.storageService,
    this.splashDuration = const Duration(seconds: 2),
    this.enableAudio = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _centerOpacity;
  late final Animation<double> _centerScale;
  AudioPlayer? _birdPlayer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _centerOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _centerScale = Tween<double>(begin: 0.84, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _playBirdSong();
    _navigationTimer = Timer(widget.splashDuration, _navigateNext);
  }

  Future<void> _playBirdSong() async {
    if (!widget.enableAudio) return;
    try {
      final player = AudioPlayer();
      _birdPlayer = player;
      await player.setAsset('assets/audio/bird_splash.wav');
      await player.setVolume(0.75);
      await player.play();
    } catch (_) {
      // Ne jamais bloquer l'écran de démarrage si l'audio matériel est indisponible
    }
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;
    try {
      await _birdPlayer?.stop();
    } catch (_) {}

    if (!mounted) return;
    final storage = widget.storageService ?? StorageService();
    if (!storage.hasSeenAppOnboarding) {
      context.go('/onboarding');
      return;
    }

    if (storage.isAuthenticated) {
      if (!storage.hasCompletedArtistOnboarding) {
        context.go('/onboarding_artists');
      } else {
        context.go('/home');
      }
      return;
    }

    context.go('/login');
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    final player = _birdPlayer;
    _birdPlayer = null;
    if (player != null) {
      unawaited(player.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Fond noir uniforme absolu (#000000)
              const ColoredBox(color: Colors.black),

              // Motif en quinconce alternant petit logo tout blanc et nouveau logo
              // (bécarre orange + cercles blancs) tout autour du logo central
              FadeTransition(
                opacity: _centerOpacity,
                child: _SurroundingLogoPattern(canvasSize: size),
              ),

              // Logo principal centré : aucun cadre orange, aucune lueur, aucun nom texte
              Center(
                child: FadeTransition(
                  opacity: _centerOpacity,
                  child: ScaleTransition(
                    scale: _centerScale,
                    child: const SonoritizVectorLogo(
                      size: 122,
                      variant: SonoritizLogoVariant.standard,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SurroundingLogoPattern extends StatelessWidget {
  final Size canvasSize;

  const _SurroundingLogoPattern({required this.canvasSize});

  @override
  Widget build(BuildContext context) {
    const double cellSpacing = 74.0;
    const double miniSize = 30.0;
    final Offset center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    const double exclusionRadius = 112.0;

    final int cols = (canvasSize.width / cellSpacing).ceil() + 2;
    final int rows = (canvasSize.height / cellSpacing).ceil() + 2;

    final List<Widget> tiles = [];
    for (int r = -1; r < rows; r++) {
      final double y = r * cellSpacing + (cellSpacing * 0.45);
      final double rowOffsetX = r.isOdd ? (cellSpacing * 0.5) : 0.0;

      for (int c = -1; c < cols; c++) {
        final double x = c * cellSpacing + rowOffsetX;
        final double dist = (Offset(x, y) - center).distance;
        if (dist < exclusionRadius) continue;

        final bool useOrangeBecarre = (r + c).isOdd;
        final double angle = ((r * 3 + c * 5) % 4) * 0.14 - 0.21;

        tiles.add(
          Positioned(
            left: x - miniSize / 2,
            top: y - miniSize / 2,
            child: Transform.rotate(
              angle: angle,
              child: SonoritizVectorLogo(
                size: miniSize,
                opacity: useOrangeBecarre ? 0.22 : 0.15,
                variant: useOrangeBecarre
                    ? SonoritizLogoVariant.orangeBecarreWhiteCircles
                    : SonoritizLogoVariant.allWhite,
              ),
            ),
          ),
        );
      }
    }

    return Stack(clipBehavior: Clip.none, children: tiles);
  }
}
