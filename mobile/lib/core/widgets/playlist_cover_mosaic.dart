import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../features/library/data/repositories/library_repository.dart';
import '../theme/app_colors.dart';

/// Affiche le visuel signature d'une playlist Sonoritiz :
/// - Pochette personnalisée si définie par l'utilisateur
/// - Sinon, triptyque studio asymétrique (pochette dominante + aperçus décalés)
///   pour éviter la grille 2x2 standard Spotify
/// - Sinon, visuel vinyle acoustique Sonoritiz pour les playlists vides
class PlaylistCoverMosaic extends StatelessWidget {
  final PlaylistModel playlist;
  final double size;
  final double? height;
  final double borderRadius;
  final bool showEdgeAccent;

  const PlaylistCoverMosaic({
    super.key,
    required this.playlist,
    this.size = 140,
    this.height,
    this.borderRadius = 10,
    this.showEdgeAccent = false,
  });

  bool _hasUsableCustomCover(String url) {
    if (url.trim().isEmpty) return false;
    if (url.startsWith("file://") || url.startsWith("http://local.image/")) {
      if (kIsWeb) return false;
      final path = url
          .replaceFirst("file://", "")
          .replaceFirst("http://local.image/", "");
      return path.isNotEmpty && File(path).existsSync();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final targetWidth = size;
    final targetHeight = height ?? size;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: targetWidth,
        height: targetHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final effectiveSize = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : (size.isFinite ? size : 140.0);

            if (_hasUsableCustomCover(playlist.coverUrl)) {
              return _buildCustomCover(playlist.coverUrl, effectiveSize);
            }

            final coverUrls = <String>[];
            for (final track in playlist.tracks) {
              if (track.coverUrl.isNotEmpty && !coverUrls.contains(track.coverUrl)) {
                coverUrls.add(track.coverUrl);
                if (coverUrls.length >= 3) break;
              }
            }

            return _buildStudioArtwork(coverUrls, effectiveSize);
          },
        ),
      ),
    );
  }

  Widget _buildCustomCover(String url, double effectiveSize) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCoverImage(url, effectiveSize),
        if (showEdgeAccent && effectiveSize >= 72)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.9),
                    AppColors.secondary.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStudioArtwork(List<String> coverUrls, double effectiveSize) {
    if (coverUrls.isEmpty) {
      return _buildDefaultPlaceholder(effectiveSize);
    }

    if (coverUrls.length == 1 || effectiveSize < 48) {
      return _buildCoverImage(coverUrls.first, effectiveSize);
    }

    if (coverUrls.length == 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 66, child: _buildCoverImage(coverUrls[0], effectiveSize)),
          Container(width: 1.5, color: const Color(0xFF0C0C0E)),
          Expanded(
            flex: 34,
            child: _buildCoverImage(coverUrls[1], effectiveSize),
          ),
        ],
      );
    }

    // 3+ pochettes : Triptyque asymétrique Sonoritiz (65% dominant vertical + colonne droite 35%)
    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 65, child: _buildCoverImage(coverUrls[0], effectiveSize)),
            Container(width: 1.5, color: const Color(0xFF0C0C0E)),
            Expanded(
              flex: 35,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildCoverImage(coverUrls[1], effectiveSize)),
                  Container(height: 1.5, color: const Color(0xFF0C0C0E)),
                  Expanded(child: _buildCoverImage(coverUrls[2], effectiveSize)),
                ],
              ),
            ),
          ],
        ),
        if (showEdgeAccent && effectiveSize >= 72)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary,
                    AppColors.secondary.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCoverImage(String url, double effectiveSize) {
    if (url.startsWith("file://") || url.startsWith("http://local.image/")) {
      final path = url
          .replaceFirst("file://", "")
          .replaceFirst("http://local.image/", "");
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultPlaceholder(effectiveSize),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => _buildDefaultPlaceholder(effectiveSize),
    );
  }

  Widget _buildDefaultPlaceholder(double effectiveSize) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1715),
            Color(0xFF101013),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _SonoritizDiscPainter(
          accentColor: AppColors.primary,
          strokeFactor: effectiveSize < 60 ? 0.8 : 1.0,
        ),
        child: Center(
          child: Container(
            width: effectiveSize * 0.28,
            height: effectiveSize * 0.28,
            decoration: BoxDecoration(
              color: const Color(0xFF141418),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.75),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              color: AppColors.primary,
              size: (effectiveSize * 0.16).clamp(12.0, 26.0),
            ),
          ),
        ),
      ),
    );
  }
}

class _SonoritizDiscPainter extends CustomPainter {
  final Color accentColor;
  final double strokeFactor;

  const _SonoritizDiscPainter({
    required this.accentColor,
    this.strokeFactor = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = (size.width < size.height ? size.width : size.height) * 0.44;
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * strokeFactor
      ..color = Colors.white.withValues(alpha: 0.07);

    for (final ratio in [0.48, 0.68, 0.88]) {
      canvas.drawCircle(center, maxR * ratio, groovePaint);
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * strokeFactor
      ..strokeCap = StrokeCap.round
      ..color = accentColor.withValues(alpha: 0.35);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxR * 0.78),
      -0.6,
      1.3,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SonoritizDiscPainter oldDelegate) => false;
}
