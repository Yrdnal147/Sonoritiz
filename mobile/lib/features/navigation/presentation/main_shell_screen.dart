import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../library/presentation/cubit/library_cubit.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/player_state.dart';
import '../../player/presentation/widgets/mini_player_widget.dart';

class MainShellScreen extends StatefulWidget {
  final Widget child;

  const MainShellScreen({
    super.key,
    required this.child,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _lastKnownTab = 0;

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;

    if (location.startsWith('/search') || location.startsWith('/category')) {
      _lastKnownTab = 1;
      return 1;
    }
    if (location.startsWith('/library') ||
        location.startsWith('/favorites') ||
        location.startsWith('/playlists') ||
        location.startsWith('/playlist') ||
        location.startsWith('/local')) {
      _lastKnownTab = 2;
      return 2;
    }
    if (location.startsWith('/connect')) {
      _lastKnownTab = 3;
      return 3;
    }
    if (location.startsWith('/profile') ||
        location.startsWith('/stats') ||
        location.startsWith('/followed') ||
        location.startsWith('/audio-settings') ||
        location.startsWith('/storage-settings') ||
        location.startsWith('/edit-profile') ||
        location.startsWith('/sound-passport') ||
        location.startsWith('/activity-capsules')) {
      _lastKnownTab = 4;
      return 4;
    }
    if (location.startsWith('/home') ||
        location.startsWith('/trends') ||
        location.startsWith('/new-releases') ||
        location.startsWith('/artist-playlist') ||
        location.startsWith('/select-artists') ||
        location.startsWith('/select_artists') ||
        location.startsWith('/quiz') ||
        location.startsWith('/podcasts')) {
      _lastKnownTab = 0;
      return 0;
    }

    // Pour les routes partagées (ex: /artist, /album), conserver l'onglet de provenance
    return _lastKnownTab;
  }

  void _onTap(int index) {
    setState(() {
      _lastKnownTab = index;
    });

    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/library');
        break;
      case 3:
        context.go('/connect');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlayerCubit, PlayerState>(
      listenWhen: (previous, current) {
        if (previous.errorMessage != current.errorMessage &&
            current.errorMessage != null) {
          return true;
        }
        if (current.currentTrack == null) return false;
        if (previous.currentTrack?.id != current.currentTrack?.id) return true;
        if (previous.position > const Duration(seconds: 5) &&
            current.position < const Duration(seconds: 1) &&
            current.isPlaying) {
          return true;
        }
        return false;
      },
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          return;
        }
        if (state.currentTrack != null) {
          context
              .read<LibraryCubit>()
              .addHistoryRecordLocal(state.currentTrack!);
        }
      },
      child: ResponsiveBuilder(
        mobile: (context) => _buildMobileLayout(context),
        tablet: (context) => _buildDesktopLayout(context),
        desktop: (context) => _buildDesktopLayout(context),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final int currentIndex = _calculateSelectedIndex(context);
    final String location = GoRouterState.of(context).uri.path;
    final bool hideMiniPlayer = location.startsWith('/edit-profile') ||
        location.startsWith('/audio-settings') ||
        location.startsWith('/storage-settings');

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      body: widget.child,
      extendBody: true,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hideMiniPlayer) const MiniPlayerWidget(),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                color: const Color(0xFF0B0B0C).withValues(alpha: 0.84),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bordure supérieure avec indicateur dynamique qui suit l'onglet actif
                      SizedBox(
                        height: 2.0,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment(
                                -1.0 + (currentIndex * (2.0 / 4)),
                                0,
                              ),
                              child: FractionallySizedBox(
                                widthFactor: 0.20,
                                child: Center(
                                  child: Container(
                                    height: 2.0,
                                    width: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(1.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.75),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                        ),
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.only(top: 5, bottom: 2),
                          child: BottomNavigationBar(
                            currentIndex: currentIndex,
                            onTap: _onTap,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            type: BottomNavigationBarType.fixed,
                            selectedItemColor: Colors.white,
                            unselectedItemColor: const Color(0xFF9898A4),
                            selectedFontSize: 12.0,
                            unselectedFontSize: 12.0,
                            selectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                            items: const [
                              BottomNavigationBarItem(
                                icon: Padding(
                                  padding: EdgeInsets.only(bottom: 5),
                                  child: _SonoritizNavIcon(
                                      type: _NavIconType.home, isActive: false),
                                ),
                                activeIcon: Padding(
                                  padding: EdgeInsets.only(bottom: 5),
                                  child: _SonoritizNavIcon(
                                      type: _NavIconType.home, isActive: true),
                                ),
                                label: AppStrings.tabHome,
                              ),
                              BottomNavigationBarItem(
                                icon: Padding(
                                  padding: EdgeInsets.only(bottom: 5),
                                  child: _SonoritizNavIcon(
                                      type: _NavIconType.search, isActive: false),
                                ),
                                activeIcon: Padding(
                                  padding: EdgeInsets.only(bottom: 5),
                                  child: _SonoritizNavIcon(
                                      type: _NavIconType.search, isActive: true),
                                ),
                                label: AppStrings.tabSearch,
                              ),
                              BottomNavigationBarItem(
                                icon: Padding(
                                  padding: EdgeInsets.only(bottom: 5),
                                  child: _SonoritizNavIcon(
                                      type: _NavIconType.library, isActive: false),
                                ),
                                activeIcon: Padding(
                                  padding: EdgeInsets.only(bottom: 5),
                                  child: _SonoritizNavIcon(
                                      type: _NavIconType.library, isActive: true),
                                ),
                                label: AppStrings.tabLibrary,
                              ),
                              BottomNavigationBarItem(
                                icon: Padding(
                                  padding: EdgeInsets.only(bottom: 5),
                                  child: _SonoritizNavIcon(
                                      type: _NavIconType.connect, isActive: false),
                                ),
                                activeIcon: Padding(
                                  padding: EdgeInsets.only(bottom: 5),
                                  child: _SonoritizNavIcon(
                                      type: _NavIconType.connect, isActive: true),
                                ),
                                label: AppStrings.tabConnect,
                              ),
                              BottomNavigationBarItem(
                                icon: Padding(
                                  padding: EdgeInsets.only(bottom: 5),
                                  child: _SonoritizNavIcon(
                                      type: _NavIconType.profile, isActive: false),
                                ),
                                activeIcon: Padding(
                                  padding: EdgeInsets.only(bottom: 5),
                                  child: _SonoritizNavIcon(
                                      type: _NavIconType.profile, isActive: true),
                                ),
                                label: AppStrings.tabProfile,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final int currentIndex = _calculateSelectedIndex(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: _onTap,
            backgroundColor: colorScheme.surface,
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: _SonoritizNavIcon(
                    type: _NavIconType.home, isActive: false),
                selectedIcon: _SonoritizNavIcon(
                    type: _NavIconType.home, isActive: true),
                label: Text(AppStrings.tabHome),
              ),
              NavigationRailDestination(
                icon: _SonoritizNavIcon(
                    type: _NavIconType.search, isActive: false),
                selectedIcon: _SonoritizNavIcon(
                    type: _NavIconType.search, isActive: true),
                label: Text(AppStrings.tabSearch),
              ),
              NavigationRailDestination(
                icon: _SonoritizNavIcon(
                    type: _NavIconType.library, isActive: false),
                selectedIcon: _SonoritizNavIcon(
                    type: _NavIconType.library, isActive: true),
                label: Text(AppStrings.tabLibrary),
              ),
              NavigationRailDestination(
                icon: _SonoritizNavIcon(
                    type: _NavIconType.connect, isActive: false),
                selectedIcon: _SonoritizNavIcon(
                    type: _NavIconType.connect, isActive: true),
                label: Text(AppStrings.tabConnect),
              ),
              NavigationRailDestination(
                icon: _SonoritizNavIcon(
                    type: _NavIconType.profile, isActive: false),
                selectedIcon: _SonoritizNavIcon(
                    type: _NavIconType.profile, isActive: true),
                label: Text(AppStrings.tabProfile),
              ),
            ],
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(child: widget.child),
                Builder(
                  builder: (context) {
                    final String location = GoRouterState.of(context).uri.path;
                    final bool hideMiniPlayer = location.startsWith('/edit-profile') ||
                        location.startsWith('/audio-settings') ||
                        location.startsWith('/storage-settings');
                    if (hideMiniPlayer) return const SizedBox.shrink();
                    return const MiniPlayerWidget();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _NavIconType { home, search, library, connect, profile }

class _SonoritizNavIcon extends StatelessWidget {
  final _NavIconType type;
  final bool isActive;

  const _SonoritizNavIcon({
    required this.type,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: CustomPaint(
        painter: _SonoritizNavIconPainter(
          type: type,
          isActive: isActive,
          activeColor: Colors.white,
          inactiveColor: const Color(0xFF9898A4),
        ),
      ),
    );
  }
}

class _SonoritizNavIconPainter extends CustomPainter {
  final _NavIconType type;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;

  _SonoritizNavIconPainter({
    required this.type,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = isActive ? activeColor : inactiveColor;

    // Traits vectoriels nets et précis sans lueur floue
    final mainPaint = Paint()
      ..color = color
      ..strokeWidth = isActive ? 2.1 : 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _drawIcon(canvas, size, mainPaint);
  }

  void _drawIcon(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    switch (type) {
      case _NavIconType.home:
        final path = Path()
          ..moveTo(w * 0.15, h * 0.42)
          ..lineTo(w * 0.50, h * 0.15)
          ..lineTo(w * 0.85, h * 0.42)
          ..lineTo(w * 0.85, h * 0.82)
          ..quadraticBezierTo(w * 0.85, h * 0.88, w * 0.79, h * 0.88)
          ..lineTo(w * 0.21, h * 0.88)
          ..quadraticBezierTo(w * 0.15, h * 0.88, w * 0.15, h * 0.82)
          ..close();
        canvas.drawPath(path, paint);

        final doorPath = Path()
          ..moveTo(w * 0.38, h * 0.88)
          ..lineTo(w * 0.38, h * 0.58)
          ..quadraticBezierTo(w * 0.38, h * 0.53, w * 0.50, h * 0.53)
          ..quadraticBezierTo(w * 0.62, h * 0.53, w * 0.62, h * 0.58)
          ..lineTo(w * 0.62, h * 0.88);
        canvas.drawPath(doorPath, paint);
        break;

      case _NavIconType.search:
        canvas.drawCircle(Offset(w * 0.44, h * 0.44), w * 0.28, paint);
        canvas.drawLine(
          Offset(w * 0.64, h * 0.64),
          Offset(w * 0.86, h * 0.86),
          paint,
        );
        break;

      case _NavIconType.library:
        // Trois livres : 2 livres verticaux + 1 livre incliné à droite
        final book1 = RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.15, h * 0.20, w * 0.30, h * 0.86),
          const Radius.circular(2.0),
        );
        final book2 = RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.35, h * 0.14, w * 0.50, h * 0.86),
          const Radius.circular(2.0),
        );

        canvas.drawRRect(book1, paint);
        canvas.drawRRect(book2, paint);

        // 3e livre incliné sur la droite
        canvas.save();
        canvas.translate(w * 0.56, h * 0.20);
        canvas.rotate(-0.24);
        final book3 = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w * 0.15, h * 0.66),
          const Radius.circular(2.0),
        );
        canvas.drawRRect(book3, paint);
        canvas.restore();
        break;

      case _NavIconType.connect:
        // Deux anneaux entrelacés (Connect)
        final r = w * 0.27;
        final leftCenter = Offset(w * 0.36, h * 0.50);
        final rightCenter = Offset(w * 0.64, h * 0.50);

        // Anneau gauche
        canvas.drawCircle(leftCenter, r, paint);
        // Anneau droit
        canvas.drawCircle(rightCenter, r, paint);
        break;

      case _NavIconType.profile:
        canvas.drawCircle(Offset(w * 0.50, h * 0.36), w * 0.19, paint);

        final body = Path()
          ..moveTo(w * 0.20, h * 0.85)
          ..quadraticBezierTo(w * 0.20, h * 0.63, w * 0.50, h * 0.63)
          ..quadraticBezierTo(w * 0.80, h * 0.63, w * 0.80, h * 0.85);
        canvas.drawPath(body, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SonoritizNavIconPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.isActive != isActive ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
