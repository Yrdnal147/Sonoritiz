import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

class _NavItemData {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const _NavItemData({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

const List<_NavItemData> _navItems = [
  _NavItemData(
    activeIcon: Icons.home_rounded,
    inactiveIcon: Icons.home_outlined,
    label: AppStrings.tabHome,
  ),
  _NavItemData(
    activeIcon: Icons.search_rounded,
    inactiveIcon: Icons.search_rounded,
    label: AppStrings.tabSearch,
  ),
  _NavItemData(
    activeIcon: Icons.library_music_rounded,
    inactiveIcon: Icons.library_music_outlined,
    label: AppStrings.tabLibrary,
  ),
  _NavItemData(
    activeIcon: Icons.sensors_rounded,
    inactiveIcon: Icons.sensors_outlined,
    label: AppStrings.tabConnect,
  ),
  _NavItemData(
    activeIcon: Icons.person_rounded,
    inactiveIcon: Icons.person_outline_rounded,
    label: AppStrings.tabProfile,
  ),
];

/// Barre de navigation flottante style capsule avec boutons circulaires,
/// inspirée du design moderne (capsule en verre dépoli + pastille orange active
/// et disques circulaires tactiles).
class SonoritizFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SonoritizFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.40),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.12),
                  const Color(0xD9181818),
                ),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_navItems.length, (index) {
                  return _NavCircleButton(
                    item: _navItems[index],
                    isSelected: currentIndex == index,
                    onTap: () => onTap(index),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCircleButton extends StatefulWidget {
  final _NavItemData item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavCircleButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavCircleButton> createState() => _NavCircleButtonState();
}

class _NavCircleButtonState extends State<_NavCircleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.isSelected;
    const primaryColor = AppColors.primary;

    return Tooltip(
      message: widget.item.label,
      waitDuration: const Duration(milliseconds: 600),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : (isSelected ? 1.06 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? primaryColor
                  : Colors.white.withValues(alpha: 0.95),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  isSelected ? widget.item.activeIcon : widget.item.inactiveIcon,
                  key: ValueKey('${widget.item.label}_$isSelected'),
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF1E1E20),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
