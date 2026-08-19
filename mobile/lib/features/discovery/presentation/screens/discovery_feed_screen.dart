import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/player/data/models/track_model.dart';
import '../cubit/discovery_cubit.dart';
import '../cubit/discovery_state.dart';
import '../widgets/audio_short_widget.dart';
import '../widgets/video_short_widget.dart';
import '../widgets/lyrics_short_widget.dart';
import 'package:go_router/go_router.dart';

class DiscoveryFeedScreen extends StatefulWidget {
  final String feedType; // 'audio', 'video', 'lyrics'

  const DiscoveryFeedScreen({Key? key, required this.feedType}) : super(key: key);

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
    context.read<DiscoveryCubit>().loadDiscoveryFeeds();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getTitle() {
    switch (widget.feedType) {
      case 'video':
        return 'Sonorités vidéo';
      case 'lyrics':
        return 'Lyrics de sonorité';
      case 'audio':
      default:
        return 'Sonorités en audios';
    }
  }

  void _handleAutoScroll() {
    if (_autoScrollEnabled && mounted) {
      _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
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
        title: Text(
          _getTitle(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _autoScrollEnabled ? Icons.autorenew_rounded : Icons.sync_disabled_rounded, 
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
                icon: Icon(isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white),
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
          if (state is DiscoveryLoading || state is DiscoveryInitial) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          } else if (state is DiscoveryError) {
            return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
          } else if (state is DiscoveryLoaded) {
            List<TrackModel> tracks;
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

            if (tracks.isEmpty) {
              return const Center(child: Text("Aucun contenu disponible", style: TextStyle(color: Colors.white)));
            }

            return PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              allowImplicitScrolling: true,
              itemCount: tracks.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final track = tracks[index];
                final isMuted = state.isMuted;
                final isActive = index == _currentIndex;
                
                switch (widget.feedType) {
                  case 'video':
                    return VideoShortWidget(track: track, isMuted: isMuted, isActive: isActive, onAutoScrollTriggered: _handleAutoScroll);
                  case 'lyrics':
                    return LyricsShortWidget(track: track, isMuted: isMuted, isActive: isActive, onAutoScrollTriggered: _handleAutoScroll);
                  case 'audio':
                  default:
                    return AudioShortWidget(track: track, isMuted: isMuted, isActive: isActive, onAutoScrollTriggered: _handleAutoScroll);
                }
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
