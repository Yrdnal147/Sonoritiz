import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/sonoritiz_brand_logo.dart';
import '../../library/presentation/cubit/library_cubit.dart';
import '../../library/presentation/cubit/library_state.dart';
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
  String _lastRouteLocation = '';
  String? _lastRecordedHistoryTrackId;
  bool _isBottomNavVisible = true;

  bool _handleScrollMetricsNotification(
      ScrollMetricsNotification notification) {
    return false;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0.0;
      final pixels = notification.metrics.pixels;
      final maxExtent = notification.metrics.maxScrollExtent;
      final bool isUserDragging = notification.dragDetails != null;

      // Sur les pages courtes (ou en rebond élastique comme Connect),
      // réagir directement au glissement du doigt sans que le rebond à 0 ne bloque le masquage.
      if (maxExtent <= 80.0) {
        if (!isUserDragging) return false;
        if (delta > 4.0 && _isBottomNavVisible) {
          setState(() => _isBottomNavVisible = false);
        } else if (delta < -4.0 && !_isBottomNavVisible) {
          setState(() => _isBottomNavVisible = true);
        }
        return false;
      }

      if (pixels <= 12.0 && delta <= 0) {
        if (!_isBottomNavVisible) {
          setState(() => _isBottomNavVisible = true);
        }
      } else if (delta > 5.5 && (pixels > 28.0 || isUserDragging)) {
        if (_isBottomNavVisible) {
          setState(() => _isBottomNavVisible = false);
        }
      } else if (delta < -5.5) {
        if (!_isBottomNavVisible) {
          setState(() => _isBottomNavVisible = true);
        }
      }
    }
    return false;
  }

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
        location.startsWith('/history') ||
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
        location.startsWith('/all-releases') ||
        location.startsWith('/collection') ||
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
      _isBottomNavVisible = true;
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
        // Enregistrer dans l'historique uniquement quand la lecture a réellement démarré
        if (current.isPlaying &&
            !current.isBuffering &&
            _lastRecordedHistoryTrackId != current.currentTrack?.id) {
          return true;
        }
        if (previous.position > const Duration(seconds: 5) &&
            current.position < const Duration(seconds: 1) &&
            current.isPlaying &&
            !current.isBuffering) {
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
        if (state.currentTrack != null && state.isPlaying && !state.isBuffering) {
          _lastRecordedHistoryTrackId = state.currentTrack!.id;
          context
              .read<LibraryCubit>()
              .addHistoryRecordLocal(state.currentTrack!);
        }
      },
      child: ResponsiveBuilder(
        mobile: (context) => _buildMobileLayout(context),
        tablet: (context) => _buildTabletLayout(context),
        desktop: (context) => _buildDesktopLayout(context),
      ),
    );
  }

  bool _shouldHideMiniPlayer(String location) {
    return location.startsWith('/edit-profile') ||
        location.startsWith('/audio-settings') ||
        location.startsWith('/storage-settings');
  }

  Widget _buildMobileLayout(BuildContext context) {
    final int currentIndex = _calculateSelectedIndex(context);
    final String location = GoRouterState.of(context).uri.path;
    if (_lastRouteLocation != location) {
      _lastRouteLocation = location;
      _isBottomNavVisible = true;
    }
    final bool hideMiniPlayer = _shouldHideMiniPlayer(location);
    final bool isNarrowFoldCover = ResponsiveUtils.isCompactNarrow(context);
    final double labelFontSize = isNarrowFoldCover ? 10.5 : 12.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      body: NotificationListener<ScrollMetricsNotification>(
        onNotification: _handleScrollMetricsNotification,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: widget.child,
        ),
      ),
      extendBody: true,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hideMiniPlayer)
            AnimatedPadding(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: _isBottomNavVisible
                    ? 0.0
                    : MediaQuery.paddingOf(context).bottom + 6.0,
              ),
              child: const MiniPlayerWidget(),
            ),
          RepaintBoundary(
            child: ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: _isBottomNavVisible ? 1.0 : 0.0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _isBottomNavVisible ? 1.0 : 0.0,
                  child: _isBottomNavVisible
                      ? BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: _buildBottomNavSurface(
                            context,
                            currentIndex: currentIndex,
                            isNarrowFoldCover: isNarrowFoldCover,
                            labelFontSize: labelFontSize,
                          ),
                        )
                      : _buildBottomNavSurface(
                          context,
                          currentIndex: currentIndex,
                          isNarrowFoldCover: isNarrowFoldCover,
                          labelFontSize: labelFontSize,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavSurface(
    BuildContext context, {
    required int currentIndex,
    required bool isNarrowFoldCover,
    required double labelFontSize,
  }) {
    return Container(
      color: const Color(0xFF0B0B0C).withValues(alpha: 0.88),
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
                          width: isNarrowFoldCover ? 28 : 36,
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
                  selectedFontSize: labelFontSize,
                  unselectedFontSize: labelFontSize,
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
              );
  }

  static const List<(_NavIconType, String)> _navEntries = [
    (_NavIconType.home, AppStrings.tabHome),
    (_NavIconType.search, AppStrings.tabSearch),
    (_NavIconType.library, AppStrings.tabLibrary),
    (_NavIconType.connect, AppStrings.tabConnect),
    (_NavIconType.profile, AppStrings.tabProfile),
  ];

  /// Layout intermédiaire (600dp – 1023dp) : Galaxy Z Fold déplié & Tablette portrait.
  /// Rail latéral sombre Signature Sonoritiz avec logo, indicateur lumineux et zone principale centrée.
  Widget _buildTabletLayout(BuildContext context) {
    final int currentIndex = _calculateSelectedIndex(context);
    final String location = GoRouterState.of(context).uri.path;
    final bool hideMiniPlayer = _shouldHideMiniPlayer(location);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      body: Row(
        children: [
          Container(
            width: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E12),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              right: false,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _onTap(0),
                    child: const SonoritizVectorLogo(
                      size: 34,
                      variant: SonoritizLogoVariant.standard,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _navEntries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final entry = _navEntries[idx];
                        final isSelected = currentIndex == idx;
                        return _SonoritizRailButton(
                          iconType: entry.$1,
                          label: entry.$2,
                          isSelected: isSelected,
                          extended: false,
                          onTap: () => _onTap(idx),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ResponsiveContentConstraint(
                    maxWidth: AppBreakpoints.maxContentWidth,
                    child: widget.child,
                  ),
                ),
                if (!hideMiniPlayer)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + kToolbarHeight + 6,
                    right: 16,
                    width: 400,
                    child: const MiniPlayerWidget(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Layout grand écran (>= 1024dp) : Tablette paysage & PC Desktop.
  /// Barre latérale complète avec identité visuelle, navigation principale et accès rapide bibliothèque.
  Widget _buildDesktopLayout(BuildContext context) {
    final int currentIndex = _calculateSelectedIndex(context);
    final String location = GoRouterState.of(context).uri.path;
    final bool hideMiniPlayer = _shouldHideMiniPlayer(location);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      body: Row(
        children: [
          Container(
            width: 248,
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E12),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              right: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: GestureDetector(
                      onTap: () => _onTap(0),
                      child: Row(
                        children: [
                          const SonoritizVectorLogo(
                            size: 32,
                            variant: SonoritizLogoVariant.standard,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppStrings.appName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: List.generate(_navEntries.length, (idx) {
                        final entry = _navEntries[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _SonoritizRailButton(
                            iconType: entry.$1,
                            label: entry.$2,
                            isSelected: currentIndex == idx,
                            extended: true,
                            onTap: () => _onTap(idx),
                          ),
                        );
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                    child: Text(
                      'VOTRE ESPACE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _SidebarQuickLink(
                          icon: Icons.favorite_rounded,
                          iconColor: AppColors.primary,
                          label: 'Titres likés',
                          isActive: location == '/favorites/tracks',
                          onTap: () => context.push('/favorites/tracks'),
                        ),
                        _SidebarQuickLink(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFFFB84D),
                          label: 'Sonoritiz Superlikes',
                          isActive: location == '/favorites/superlikes',
                          onTap: () => context.push('/favorites/superlikes'),
                        ),
                        _SidebarQuickLink(
                          icon: Icons.album_rounded,
                          iconColor: Colors.white70,
                          label: 'Albums favoris',
                          isActive: location == '/favorites/albums',
                          onTap: () => context.push('/favorites/albums'),
                        ),
                        _SidebarQuickLink(
                          icon: Icons.people_alt_rounded,
                          iconColor: Colors.white70,
                          label: 'Artistes suivis',
                          isActive: location == '/followed',
                          onTap: () => context.push('/followed'),
                        ),
                        const SizedBox(height: 12),
                        BlocBuilder<LibraryCubit, LibraryState>(
                          builder: (context, libState) {
                            if (libState is! LibraryLoaded ||
                                libState.playlists.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final topPlaylists = libState.playlists.take(6).toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                                  child: Text(
                                    'PLAYLISTS',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.42),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                                for (final pl in topPlaylists)
                                  _SidebarQuickLink(
                                    icon: pl.isPinned
                                        ? Icons.push_pin_rounded
                                        : Icons.queue_music_rounded,
                                    iconColor: pl.isPinned
                                        ? AppColors.primary
                                        : Colors.white54,
                                    label: pl.name,
                                    isActive: false,
                                    onTap: () => context.push('/playlist', extra: pl),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ResponsiveContentConstraint(
                    maxWidth: AppBreakpoints.maxContentWidth,
                    child: widget.child,
                  ),
                ),
                if (!hideMiniPlayer)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + kToolbarHeight + 6,
                    right: 16,
                    width: 400,
                    child: const MiniPlayerWidget(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SonoritizRailButton extends StatefulWidget {
  final _NavIconType iconType;
  final String label;
  final bool isSelected;
  final bool extended;
  final VoidCallback onTap;

  const _SonoritizRailButton({
    required this.iconType,
    required this.label,
    required this.isSelected,
    required this.extended,
    required this.onTap,
  });

  @override
  State<_SonoritizRailButton> createState() => _SonoritizRailButtonState();
}

class _SonoritizRailButtonState extends State<_SonoritizRailButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.extended ? 14 : 6,
            vertical: widget.extended ? 11 : 10,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.15)
                : (_hovered
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.42)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: widget.extended
              ? Row(
                  children: [
                    _SonoritizNavIcon(
                      type: widget.iconType,
                      isActive: active,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? Colors.white : const Color(0xFFA8A8B3),
                          fontSize: 14,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (active)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SonoritizNavIcon(
                      type: widget.iconType,
                      isActive: active,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? Colors.white : const Color(0xFF9898A4),
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SidebarQuickLink extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarQuickLink({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarQuickLink> createState() => _SidebarQuickLinkState();
}

class _SidebarQuickLinkState extends State<_SidebarQuickLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: widget.isActive || _hovered
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: widget.iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    fontWeight:
                        widget.isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
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
