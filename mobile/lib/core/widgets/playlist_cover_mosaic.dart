import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../features/library/data/repositories/library_repository.dart';
import '../theme/app_colors.dart';

/// A widget that displays a playlist cover as a mosaic of track covers.
/// - 4+ tracks: 2x2 grid of the first 4 covers
/// - 3 tracks: top half = 1 cover, bottom half = 2 covers side by side
/// - 2 tracks: 2 covers side by side
/// - 1 track: single full cover
/// - 0 tracks: default placeholder icon
///
/// If the playlist has a custom coverUrl set, that is shown instead.
class PlaylistCoverMosaic extends StatelessWidget {
  final PlaylistModel playlist;
  final double size;
  final double borderRadius;

  const PlaylistCoverMosaic({
    Key? key,
    required this.playlist,
    this.size = 140,
    this.borderRadius = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If the playlist has a custom cover image set by the user, show that.
    if (playlist.coverUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: size,
          height: size,
          child: _buildCoverImage(playlist.coverUrl),
        ),
      );
    }

    // Collect unique cover URLs from the playlist tracks
    final coverUrls = <String>[];
    for (final track in playlist.tracks) {
      if (track.coverUrl.isNotEmpty && !coverUrls.contains(track.coverUrl)) {
        coverUrls.add(track.coverUrl);
        if (coverUrls.length >= 4) break;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: _buildMosaic(coverUrls),
      ),
    );
  }

  Widget _buildMosaic(List<String> coverUrls) {
    if (coverUrls.isEmpty) {
      return _buildDefaultPlaceholder();
    }

    if (coverUrls.length == 1) {
      return _buildSingleImage(coverUrls[0]);
    }

    if (coverUrls.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildSingleImage(coverUrls[0])),
          Expanded(child: _buildSingleImage(coverUrls[1])),
        ],
      );
    }

    if (coverUrls.length == 3) {
      return Column(
        children: [
          Expanded(child: _buildSingleImage(coverUrls[0])),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildSingleImage(coverUrls[1])),
                Expanded(child: _buildSingleImage(coverUrls[2])),
              ],
            ),
          ),
        ],
      );
    }

    // 4 covers: 2x2 grid
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildSingleImage(coverUrls[0])),
              Expanded(child: _buildSingleImage(coverUrls[1])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildSingleImage(coverUrls[2])),
              Expanded(child: _buildSingleImage(coverUrls[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleImage(String url) {
    return _buildCoverImage(url);
  }

  Widget _buildCoverImage(String url) {
    if (url.startsWith("file://")) {
      return Image.file(
        File(url.replaceFirst("file://", "")),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultPlaceholder(),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => _buildDefaultPlaceholder(),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Icon(
          Icons.queue_music_rounded,
          color: Colors.white.withOpacity(0.3),
          size: size * 0.4,
        ),
      ),
    );
  }
}
