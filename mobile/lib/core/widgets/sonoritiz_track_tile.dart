import 'package:flutter/material.dart';
import '../theme/app_dimensions.dart';
import 'sonoritiz_artwork.dart';
import 'artist_name_display.dart';

class SonoritizTrackTile extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isPlaying;

  const SonoritizTrackTile({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.isPlaying = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: "Jouer $title",
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SonoritizArtwork(
                    imageUrl: imageUrl,
                    width: 56.0,
                    height: 56.0,
                    borderRadius: AppDimensions.radiusSm,
                  ),
                  if (isPlaying)
                    Container(
                      width: 56.0,
                      height: 56.0,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.equalizer_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: isPlaying ? colorScheme.primary : colorScheme.onSurface,
                        fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ArtistNameDisplay(
                      artistName: subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
