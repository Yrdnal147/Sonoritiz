import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sonoritiz/core/theme/app_colors.dart';
import 'package:sonoritiz/core/theme/app_dimensions.dart';
import 'package:sonoritiz/core/widgets/superlike_vibration_heart.dart';
import 'package:sonoritiz/features/player/data/models/track_model.dart';
import 'package:sonoritiz/features/player/presentation/cubit/superlike_cubit.dart';
import 'package:sonoritiz/features/player/presentation/cubit/superlike_state.dart';
import 'package:sonoritiz/features/library/presentation/cubit/library_cubit.dart';
import 'package:sonoritiz/features/library/presentation/cubit/library_state.dart';

class PlayerFavoriteButton extends StatefulWidget {
  final TrackModel track;
  final double size;
  final double iconSize;

  const PlayerFavoriteButton({
    Key? key,
    required this.track,
    this.size = AppDimensions.minTouchTarget,
    this.iconSize = 30.0,
  }) : super(key: key);

  @override
  State<PlayerFavoriteButton> createState() => _PlayerFavoriteButtonState();
}

class _PlayerFavoriteButtonState extends State<PlayerFavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapFavorite(bool isFav) {
    HapticFeedback.lightImpact();
    _animController.forward(from: 0.0);
    final cubit = context.read<LibraryCubit>();
    if (isFav) {
      cubit.removeFavorite(widget.track.id);
    } else {
      cubit.addFavorite(widget.track);
    }
  }

  void _onTapSuperlike() {
    HapticFeedback.mediumImpact();
    _animController.forward(from: 0.0);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF1E140F),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        content: Row(
          children: [
            SuperlikeVibrationHeart(
              size: SuperlikeBadgeSize.small,
              showBackground: false,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Sonoritiz Superlike actif ! Double-cliquez sur la pochette pour le retirer.",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SuperlikeCubit, SuperlikeState, bool>(
      selector: (state) => state.isSuperliked(widget.track.id),
      builder: (context, isSuperliked) {
        if (isSuperliked) {
          return Semantics(
            button: true,
            label: "Sonoritiz Superlike",
            child: Tooltip(
              message: "Sonoritiz Superlike (Double-cliquez sur la pochette pour retirer)",
              child: GestureDetector(
                onTap: _onTapSuperlike,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Center(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6D00).withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: SuperlikeVibrationHeart(
                          size: widget.iconSize > 24
                              ? SuperlikeBadgeSize.large
                              : SuperlikeBadgeSize.medium,
                          showBackground: false,
                          isActive: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return BlocSelector<LibraryCubit, LibraryState, bool>(
          selector: (state) => context.read<LibraryCubit>().isFavorite(
                widget.track.id,
                title: widget.track.title,
                artist: widget.track.artistName,
              ),
          builder: (context, isFav) {

            return Semantics(
              button: true,
              label: isFav ? "Retirer des favoris" : "Ajouter aux favoris",
              child: Tooltip(
                message: isFav ? "Retirer des favoris" : "Ajouter aux favoris",
                child: GestureDetector(
                  onTap: () => _onTapFavorite(isFav),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: Center(
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? AppColors.primary : Colors.white,
                          size: widget.iconSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
