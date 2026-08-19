import 'package:flutter/material.dart';
import '../theme/app_dimensions.dart';
import 'sonoritiz_artwork.dart';
import 'artist_name_display.dart';

class SonoritizTrackCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double width;
  final String? tag; // Pour le Hero animation

  const SonoritizTrackCard({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.width = 140.0,
    this.tag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget artwork = SonoritizArtwork(
      imageUrl: imageUrl,
      width: width,
      height: width,
      borderRadius: AppDimensions.radiusMd,
    );

    if (tag != null) {
      artwork = Hero(tag: tag!, child: artwork);
    }

    return Semantics(
      button: true,
      label: "Jouer $title par $subtitle",
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              artwork,
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              ArtistNameDisplay(
                artistName: subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
