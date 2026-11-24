import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/screen_wake_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sonoritiz_page_title.dart';
import '../../../../features/player/data/models/track_model.dart';
import '../../../../features/player/presentation/cubit/player_cubit.dart';
import '../cubit/discovery_cubit.dart';
import '../cubit/discovery_state.dart';
import '../widgets/audio_short_widget.dart';
import '../widgets/video_short_widget.dart';
import '../widgets/lyrics_short_widget.dart';

class DiscoveryFeedScreen extends StatefulWidget {
  final String feedType; // 'audio', 'video', 'lyrics'
  final List<TrackModel>? customTracks;
  final String? artistName;
  final int clipDurationSeconds;
  final bool focusHighlight;

  const DiscoveryFeedScreen({
    super.key,
    required this.feedType,
    this.customTracks,
    this.artistName,
    this.clipDurationSeconds = 20,
    this.focusHighlight = false,
  });

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _autoScrollEnabled = false;

  @override
  void initState() {
    super.initState();
    // Empêche l'extinction / verrouillage de l'écran pendant les Sonoritiz Shorts
    ScreenWakeService.setKeepScreenOn(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Mettre en pause le lecteur principal pour éviter toute superposition sonore
        context.read<PlayerCubit>().pause();
      }
    });
    if (widget.customTracks == null || widget.customTracks!.isEmpty) {
      context.read<DiscoveryCubit>().loadDiscoveryFeeds();
    }
  }

  @override
  void dispose() {
    ScreenWakeService.setKeepScreenOn(false);
    _pageController.dispose();
    super.dispose();
  }

  String _getTitle() {
    final prefix = (widget.artistName != null && widget.artistName!.trim().isNotEmpty)
        ? '${widget.artistName!.trim()} • '
        : '';
    switch (widget.feedType) {
      case 'video':
        return '${prefix}Clips Vidéo';
      case 'lyrics':
        return '${prefix}Karaoké Lyrics';
      case 'audio':
      default:
        return '${prefix}Shorts Audio';
    }
  }

  void _handleAutoScroll() {
    if (_autoScrollEnabled && mounted && _pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: SonoritizPageTitle(
          title: _getTitle(),
          fontSize: 20,
          centered: true,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _autoScrollEnabled
                  ? Icons.autorenew_rounded
                  : Icons.sync_disabled_rounded,
              color: _autoScrollEnabled ? AppColors.primary : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _autoScrollEnabled = !_autoScrollEnabled;
              });
            },
          ),
          BlocBuilder<DiscoveryCubit, DiscoveryState>(
            builder: (context, state) {
              final isMuted = state is DiscoveryLoaded ? state.isMuted : false;
              return IconButton(
                icon: Icon(
                  isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  context.read<DiscoveryCubit>().toggleMute();
                },
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<DiscoveryCubit, DiscoveryState>(
        builder: (context, state) {
          final bool hasCustom =
              widget.customTracks != null && widget.customTracks!.isNotEmpty;
          final bool isMuted =
              state is DiscoveryLoaded ? state.isMuted : false;

          if (!hasCustom &&
              (state is DiscoveryLoading || state is DiscoveryInitial)) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          } else if (!hasCustom && state is DiscoveryError) {
            return Center(
                child: Text(state.message,
                    style: const TextStyle(color: AppColors.error)));
          }

          List<TrackModel> tracks = [];
          if (hasCustom) {
            tracks = widget.customTracks!;
          } else if (state is DiscoveryLoaded) {
            switch (widget.feedType) {
              case 'video':
                tracks = state.videoTracks;
                break;
              case 'lyrics':
                tracks = state.lyricsTracks;
                break;
              case 'audio':
              default:
                tracks = state.audioTracks;
                break;
            }
          }

          if (tracks.isEmpty) {
            return const Center(
                child: Text("Aucun contenu disponible",
                    style: TextStyle(color: Colors.white)));
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: false,
            itemCount: tracks.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final track = tracks[index];
              final isActive = index == _currentIndex;

              switch (widget.feedType) {
                case 'video':
                  return VideoShortWidget(
                    track: track,
                    isMuted: isMuted,
                    isActive: isActive,
                    onAutoScrollTriggered: _handleAutoScroll,
                    clipDurationSeconds: widget.clipDurationSeconds,
                    focusHighlight: widget.focusHighlight,
                  );
                case 'lyrics':
                  return LyricsShortWidget(
                    track: track,
                    isMuted: isMuted,
                    isActive: isActive,
                    onAutoScrollTriggered: _handleAutoScroll,
                    clipDurationSeconds: widget.clipDurationSeconds,
                    focusHighlight: widget.focusHighlight,
                  );
                case 'audio':
                default:
                  return AudioShortWidget(
                    track: track,
                    isMuted: isMuted,
                    isActive: isActive,
                    onAutoScrollTriggered: _handleAutoScroll,
                    clipDurationSeconds: widget.clipDurationSeconds,
                    focusHighlight: widget.focusHighlight,
                  );
              }
            },
          );
        },
      ),
    );
  }
}
