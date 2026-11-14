import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../../features/player/presentation/cubit/player_cubit.dart';
import '../../../features/player/presentation/cubit/player_state.dart';
import '../theme/app_colors.dart';

class PlayingIndicatorOverlay extends StatelessWidget {
  final String trackId;
  final Widget child;

  const PlayingIndicatorOverlay({
    Key? key,
    required this.trackId,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerCubit, PlayerState, bool>(
      selector: (state) => state.currentTrack?.id == trackId && state.isPlaying,
      builder: (context, isPlaying) {
        if (!isPlaying) return child;
        return Stack(
          alignment: Alignment.center,
          children: [
            child,
            Container(
              color: Colors.black.withOpacity(0.5),
            ),
            SpinKitWave(
              color: AppColors.secondary,
              size: 20.0,
            ),
          ],
        );
      },
    );
  }
}
