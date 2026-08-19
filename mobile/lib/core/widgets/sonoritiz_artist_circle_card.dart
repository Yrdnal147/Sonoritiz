import 'package:flutter/material.dart';
import '../theme/app_dimensions.dart';
import 'sonoritiz_artwork.dart';

class SonoritizArtistCircleCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final VoidCallback onTap;
  final double size;

  const SonoritizArtistCircleCard({
    Key? key,
    required this.imageUrl,
    required this.name,
    required this.onTap,
    this.size = 140.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: "Ouvrir l'artiste $name",
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          child: Column(
            children: [
              SonoritizArtwork(
                imageUrl: imageUrl,
                width: size,
                height: size,
                shape: BoxShape.circle,
                fallbackIcon: Icon(
                  Icons.person_rounded,
                  size: size * 0.4,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
