import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';
import '../../data/models/track_model.dart';
import '../../data/models/lyrics_model.dart';
import '../../data/services/lyrics_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({Key? key}) : super(key: key);

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  final LyricsService _lyricsService = LyricsService();
  Future<LyricsModel?>? _lyricsFuture;
  String? _currentTrackId;
  int _syncOffsetMilliseconds = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<PlayerCubit, PlayerState>(
        builder: (context, state) {
          final track = state.currentTrack;
          if (track == null) {
            return const Center(
              child: Text("Aucun morceau en cours", style: TextStyle(color: Colors.white)),
            );
          }

          // Fetch only if track changed
          if (_currentTrackId != track.id) {
            _currentTrackId = track.id;
            _lyricsFuture = _lyricsService.getLyrics(track.id, track.artistName, track.title, track.durationSeconds);
          }

          return Stack(
            children: [
              // Arrière-plan ambiant flouté (comme le lecteur)
              Positioned.fill(
                child: track.coverUrl.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: track.coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(color: AppColors.background),
                          ),
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 55.0, sigmaY: 55.0),
                            child: Container(
                              color: Colors.black.withOpacity(0.6), // Assombrir un peu plus pour les paroles
                            ),
                          ),
                        ],
                      )
                    : Container(color: AppColors.background),
              ),

              // Contenu principal
              SafeArea(
                child: Column(
                  children: [
                    // AppBar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 36, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  track.title,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  track.artistName,
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),

                    // Vue des paroles (Dynamique)
                    Expanded(
                      child: FutureBuilder<LyricsModel?>(
                        future: _lyricsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            );
                          }

                          final lyricsModel = snapshot.data;
                          if (lyricsModel == null || (!lyricsModel.hasSynced && !lyricsModel.hasPlain)) {
                            return Center(
                              child: Text(
                                "Paroles indisponibles pour ce titre.",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 18,
                                ),
                              ),
                            );
                          }

                          if (lyricsModel.hasSynced) {
                            return Column(
                              children: [
                                // Contrôles de synchronisation
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.fast_rewind_rounded, color: Colors.white70),
                                        tooltip: "Retarder les paroles",
                                        onPressed: () {
                                          setState(() { _syncOffsetMilliseconds -= 500; });
                                        },
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _syncOffsetMilliseconds == 0 
                                              ? "Sync" 
                                              : "${_syncOffsetMilliseconds > 0 ? '+' : ''}${(_syncOffsetMilliseconds / 1000.0).toStringAsFixed(1)}s",
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.fast_forward_rounded, color: Colors.white70),
                                        tooltip: "Avancer les paroles",
                                        onPressed: () {
                                          setState(() { _syncOffsetMilliseconds += 500; });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: SyncedLyricsWidget(
                                    lines: lyricsModel.parsedSyncedLyrics!,
                                    currentPosition: state.position,
                                    syncOffsetMilliseconds: _syncOffsetMilliseconds,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return ListView(
                              padding: const EdgeInsets.all(32.0),
                              physics: const BouncingScrollPhysics(),
                              children: [
                                Text(
                                  lyricsModel.plainLyrics!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SyncedLyricsWidget extends StatefulWidget {
  final List<LrcLine> lines;
  final Duration currentPosition;
  final int syncOffsetMilliseconds;

  const SyncedLyricsWidget({
    Key? key, 
    required this.lines, 
    required this.currentPosition,
    this.syncOffsetMilliseconds = 0,
  }) : super(key: key);

  @override
  State<SyncedLyricsWidget> createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget> {
  final ScrollController _scrollController = ScrollController();
  int _lastScrollIndex = -1;
  bool _isManualScrolling = false;
  Timer? _resumeScrollTimer;

  @override
  void dispose() {
    _resumeScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int index) {
    if (_isManualScrolling || !_scrollController.hasClients) return;
    
    final offset = (index * 55.0) - (MediaQuery.of(context).size.height / 3);
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    int activeIndex = -1;
    final adjustedPosition = widget.currentPosition.inMilliseconds + widget.syncOffsetMilliseconds;

    for (int i = 0; i < widget.lines.length; i++) {
      if (adjustedPosition >= widget.lines[i].time.inMilliseconds) {
        activeIndex = i;
      } else {
        break;
      }
    }

    if (activeIndex != _lastScrollIndex && activeIndex != -1) {
      _lastScrollIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLine(activeIndex);
      });
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollStartNotification && scrollNotification.dragDetails != null) {
          _isManualScrolling = true;
          _resumeScrollTimer?.cancel();
        } else if (scrollNotification is ScrollEndNotification) {
          _resumeScrollTimer?.cancel();
          _resumeScrollTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              _isManualScrolling = false;
              if (_lastScrollIndex != -1) {
                _scrollToActiveLine(_lastScrollIndex);
              }
            }
          });
        }
        return false;
      },
      child: ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).size.height / 3,
        bottom: MediaQuery.of(context).size.height / 2,
        left: 24.0,
        right: 24.0,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: widget.lines.length,
      itemBuilder: (context, index) {
        final line = widget.lines[index];
        final isActive = index == activeIndex;
        
        return GestureDetector(
          onTap: () {
            // Se positionner dans la musique au moment exact de cette parole
            context.read<PlayerCubit>().seek(line.time);
            _isManualScrolling = false;
            _resumeScrollTimer?.cancel();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              line.text.isEmpty ? "..." : line.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
                fontSize: isActive ? 28 : 22,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                shadows: isActive
                    ? [
                        Shadow(
                          color: AppColors.primary.withOpacity(0.6),
                          blurRadius: 15,
                        )
                      ]
                    : null,
              ),
            ).animate(target: isActive ? 1 : 0).scaleXY(begin: 1.0, end: 1.05, duration: 300.ms),
          ),
        );
      },
    ));
  }
}
