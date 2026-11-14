import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';

/// Curseur tactile moderne Sonoritiz pour l'atténuation / suppression de la voix (Vocal Remover)
class VocalRemoverSlider extends StatelessWidget {
  final Color accentColor;
  final bool isVertical;
  final bool showHeader;

  const VocalRemoverSlider({
    super.key,
    this.accentColor = AppColors.primary,
    this.isVertical = false,
    this.showHeader = true,
  });

  String _formatLevelLabel(double level) {
    if (level <= 0.05) return 'Voix originale';
    if (level >= 0.95) return 'Instrumentale Karaoké';
    return 'Guide vocal ${(level * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      buildWhen: (prev, cur) =>
          prev.vocalAttenuationLevel != cur.vocalAttenuationLevel,
      builder: (context, state) {
        final level = state.vocalAttenuationLevel;
        final isActive = level > 0.05;

        if (isVertical) {
          return _buildVerticalLayout(context, level, isActive);
        }

        return _buildHorizontalLayout(context, level, isActive);
      },
    );
  }

  Widget _buildHorizontalLayout(
      BuildContext context, double level, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isActive
              ? accentColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.12),
          width: isActive ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? accentColor.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive
                        ? Icons.mic_external_off_rounded
                        : Icons.mic_none_rounded,
                    size: 18,
                    color: isActive ? accentColor : Colors.white70,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vocal Remover (Karaoké)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _formatLevelLabel(level),
                        style: TextStyle(
                          color: isActive ? accentColor : Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bouton bascule 0% / 100%
                TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    final next = level >= 0.5 ? 0.0 : 1.0;
                    context.read<PlayerCubit>().setVocalAttenuation(next);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: isActive
                        ? accentColor.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.08),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isActive ? 'Réinitialiser' : 'Karaoké Max',
                    style: TextStyle(
                      color: isActive ? accentColor : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              const Icon(Icons.record_voice_over_rounded,
                  size: 16, color: Colors.white54),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6,
                    activeTrackColor: accentColor,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                    thumbColor: Colors.white,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 9),
                    overlayColor: accentColor.withValues(alpha: 0.24),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 18),
                  ),
                  child: Slider(
                    value: level,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      context.read<PlayerCubit>().setVocalAttenuation(val);
                    },
                  ),
                ),
              ),
              const Icon(Icons.music_note_rounded,
                  size: 16, color: Colors.white54),
            ],
          ),
          // Raccourcis de paliers (0%, 50%, 100%)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPresetChip(context, '0% Voix', 0.0, level == 0.0),
              _buildPresetChip(
                  context, '50% Guide', 0.5, level >= 0.45 && level <= 0.55),
              _buildPresetChip(context, '100% Solo', 1.0, level >= 0.95),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalLayout(
      BuildContext context, double level, bool isActive) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? accentColor.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.14),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              final next = level >= 0.5 ? 0.0 : 1.0;
              context.read<PlayerCubit>().setVocalAttenuation(next);
            },
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isActive
                    ? accentColor.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive
                    ? Icons.mic_external_off_rounded
                    : Icons.mic_rounded,
                size: 20,
                color: isActive ? accentColor : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(level * 100).round()}%',
            style: TextStyle(
              color: isActive ? accentColor : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  activeTrackColor: accentColor,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                  thumbColor: Colors.white,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayColor: accentColor.withValues(alpha: 0.2),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: level,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    context.read<PlayerCubit>().setVocalAttenuation(val);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isActive ? 'Karaoké' : 'Voix',
            style: TextStyle(
              color: isActive ? accentColor : Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(
      BuildContext context, String label, double targetVal, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<PlayerCubit>().setVocalAttenuation(targetVal);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentColor : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Bouton compact d'en-tête permettant d'ouvrir la jauge Vocal Remover
class VocalRemoverCompactButton extends StatelessWidget {
  final Color accentColor;

  const VocalRemoverCompactButton({
    super.key,
    this.accentColor = AppColors.primary,
  });

  void _showModal(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: const Color(0xFF14131B).withValues(alpha: 0.94),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  VocalRemoverSlider(
                    accentColor: accentColor,
                    showHeader: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      buildWhen: (prev, cur) =>
          prev.vocalAttenuationLevel != cur.vocalAttenuationLevel,
      builder: (context, state) {
        final level = state.vocalAttenuationLevel;
        final isActive = level > 0.05;

        return Tooltip(
          message: 'Vocal Remover / Mode Karaoké',
          child: GestureDetector(
            onTap: () => _showModal(context),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? accentColor.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? accentColor.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.16),
                  width: isActive ? 1.2 : 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive
                        ? Icons.mic_external_off_rounded
                        : Icons.mic_rounded,
                    size: 16,
                    color: isActive ? accentColor : Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isActive ? '${(level * 100).round()}%' : 'Karaoké',
                    style: TextStyle(
                      color: isActive ? accentColor : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
