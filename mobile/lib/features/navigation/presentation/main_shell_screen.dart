import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../player/presentation/widgets/mini_player_widget.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/player_state.dart';
import '../../library/presentation/cubit/library_cubit.dart';

class MainShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({
    Key? key,
    required this.navigationShell,
  }) : super(key: key);

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlayerCubit, PlayerState>(
      listenWhen: (previous, current) => previous.currentTrack?.id != current.currentTrack?.id,
      listener: (context, state) {
        if (state.currentTrack != null) {
          context.read<LibraryCubit>().addHistoryRecordLocal(state.currentTrack!);
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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayerWidget(),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.85),
                  border: Border(
                    top: BorderSide(color: colorScheme.outline.withOpacity(0.2), width: 1),
                  ),
                ),
                child: BottomNavigationBar(
                  currentIndex: navigationShell.currentIndex,
                  onTap: _onTap,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.home_outlined)),
                      activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.home_rounded)),
                      label: AppStrings.tabHome,
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.search_outlined)),
                      activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.search_rounded)),
                      label: AppStrings.tabSearch,
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.library_music_outlined)),
                      activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.library_music_rounded)),
                      label: AppStrings.tabLibrary,
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.sensors_outlined)),
                      activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.sensors_rounded)),
                      label: AppStrings.tabConnect,
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person_outline)),
                      activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person_rounded)),
                      label: AppStrings.tabProfile,
                    ),
                  ],
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

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            backgroundColor: colorScheme.surface,
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: Text(AppStrings.tabHome),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search_rounded),
                label: Text(AppStrings.tabSearch),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music_rounded),
                label: Text(AppStrings.tabLibrary),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sensors_outlined),
                selectedIcon: Icon(Icons.sensors_rounded),
                label: Text(AppStrings.tabConnect),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: Text(AppStrings.tabProfile),
              ),
            ],
          ),
          VerticalDivider(thickness: 1, width: 1, color: colorScheme.outline.withOpacity(0.2)),
          Expanded(
            child: Column(
              children: [
                Expanded(child: navigationShell),
                const MiniPlayerWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
