import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../search/presentation/cubit/search_cubit.dart';
import '../../data/models/track_model.dart';

class TrackDetailsContextModal extends StatefulWidget {
  final TrackModel track;
  final String playbackSource;

  const TrackDetailsContextModal({
    Key? key,
    required this.track,
    this.playbackSource = '',
  }) : super(key: key);

  static Future<void> show(
    BuildContext context,
    TrackModel track, {
    String playbackSource = '',
  }) {
    HapticFeedback.mediumImpact();
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Informations sur le son',
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return BlocProvider.value(
          value: context.read<SearchCubit>(),
          child: TrackDetailsContextModal(
            track: track,
            playbackSource: playbackSource,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 24 * animation.value,
            sigmaY: 24 * animation.value,
          ),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<TrackDetailsContextModal> createState() => _TrackDetailsContextModalState();
}

class _TrackDetailsContextModalState extends State<TrackDetailsContextModal> {
  bool _isLoading = true;
  String _albumTitle = '';
  String _albumCover = '';
  String _albumYear = '';
  int? _albumId;
  List<Map<String, dynamic>> _artists = [];
  int? _pressedArtistIndex;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  List<String> _parseArtistNames(String raw) {
    final parts = raw
        .split(
          RegExp(
            r'\s+(?:feat\.?|ft\.?|featuring|&|and|x)\s+|,\s+',
            caseSensitive: false,
          ),
        )
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return [raw.trim()];
    final unique = <String>[];
    for (final p in parts) {
      if (!unique.any((u) => u.toLowerCase() == p.toLowerCase())) {
        unique.add(p);
      }
    }
    return unique;
  }

  Future<void> _initData() async {
    final track = widget.track;
    String albumTitle = track.albumName.trim();
    if (albumTitle == 'YouTube Audio' || albumTitle == 'Local Audio' || albumTitle == 'Unknown Album') {
      albumTitle = '';
    }
    String albumCover = track.coverUrl;
    String albumYear = '';
    int? albumId;

    final List<String> artistNames = _parseArtistNames(track.artistName);

    // 1. Si c'est un titre Deezer, enrichir avec les données exactes d'album et contributors
    if (track.id.startsWith('deezer_')) {
      try {
        final dzId = track.id.replaceFirst('deezer_', '');
        final dio = Dio();
        final res = await dio.get('https://api.deezer.com/track/$dzId');
        if (res.statusCode == 200 && res.data is Map) {
          final data = res.data as Map<String, dynamic>;
          if (data['album'] is Map) {
            final alb = data['album'] as Map;
            albumId = alb['id'] is int ? alb['id'] as int : int.tryParse('${alb['id']}');
            final dzAlbumTitle = (alb['title'] ?? '').toString().trim();
            if (dzAlbumTitle.isNotEmpty) albumTitle = dzAlbumTitle;
            final dzAlbumCover = (alb['cover_xl'] ?? alb['cover_big'] ?? alb['cover_medium'] ?? '').toString();
            if (dzAlbumCover.isNotEmpty) albumCover = dzAlbumCover;
            final rel = (alb['release_date'] ?? data['release_date'] ?? '').toString();
            if (rel.length >= 4) albumYear = rel.substring(0, 4);
          }
          if (data['contributors'] is List) {
            for (final c in (data['contributors'] as List)) {
              if (c is Map && c['name'] != null) {
                final cName = c['name'].toString().trim();
                if (cName.isNotEmpty &&
                    !artistNames.any((a) => a.toLowerCase() == cName.toLowerCase())) {
                  artistNames.add(cName);
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // Afficher immédiatement la structure initiale avant même la fin des requêtes artistes
    if (mounted) {
      setState(() {
        _albumTitle = albumTitle;
        _albumCover = albumCover;
        _albumYear = albumYear;
        _albumId = albumId;
        _artists = artistNames.asMap().entries.map((e) {
          return {
            'name': e.value,
            'role': e.key == 0 ? 'Artiste principal' : 'En featuring',
            'picture_xl': '',
            'nb_fan': 0,
          };
        }).toList();
      });
    }

    // 2. Récupérer les vraies photos et statistiques de chaque artiste en parallèle
    try {
      final repo = context.read<SearchCubit>().repository;
      final fetched = await Future.wait(
        artistNames.asMap().entries.map((entry) async {
          final idx = entry.key;
          final name = entry.value;
          try {
            final details = await repo.getArtistDetailsDeezer(name);
            return {
              'name': (details['name'] ?? name).toString(),
              'role': idx == 0 ? 'Artiste principal' : 'En featuring',
              'picture_xl': (details['picture_xl'] ?? '').toString(),
              'nb_fan': (details['nb_fan'] ?? 0) as int,
            };
          } catch (_) {
            return {
              'name': name,
              'role': idx == 0 ? 'Artiste principal' : 'En featuring',
              'picture_xl': '',
              'nb_fan': 0,
            };
          }
        }),
      );

      if (mounted) {
        setState(() {
          _artists = fetched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatFans(int count) {
    return NumberFormat.decimalPattern('fr').format(count);
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _navigateToArtist(String artistName) {
    HapticFeedback.mediumImpact();
    final router = GoRouter.of(context);
    Navigator.of(context, rootNavigator: true).popUntil((route) => route is! PopupRoute);
    router.push('/artist', extra: {'name': artistName});
  }

  void _navigateToAlbum() {
    if (_albumId == null || _albumId == 0) return;
    HapticFeedback.selectionClick();
    final router = GoRouter.of(context);
    final albumMap = {
      'id': _albumId,
      'title': _albumTitle,
      'cover_xl': _albumCover,
      'release_date': _albumYear,
    };
    final mainArtist = _artists.isNotEmpty ? _artists.first['name'].toString() : widget.track.artistName;
    Navigator.of(context, rootNavigator: true).popUntil((route) => route is! PopupRoute);
    router.push('/album', extra: {'album': albumMap, 'artistName': mainArtist});
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final durationStr = _formatDuration(track.durationSeconds);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430, maxHeight: 620),
            decoration: BoxDecoration(
              color: const Color(0xFF140D10).withOpacity(0.88),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.14),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.65),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.18),
                  blurRadius: 32,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. EN-TÊTE : Pochette & Titre à tailles réduites ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.45),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SonoritizArtwork(
                            imageUrl: track.coverUrl,
                            width: 56,
                            height: 56,
                            borderRadius: 14,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (durationStr.isNotEmpty) ...[
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 13,
                                      color: Colors.white.withOpacity(0.55),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      durationStr,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (widget.playbackSource.isNotEmpty) ...[
                                    if (durationStr.isNotEmpty)
                                      Text(
                                        "  •  ",
                                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                      ),
                                    Flexible(
                                      child: Text(
                                        "Écouté depuis ${widget.playbackSource}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.tertiary.withOpacity(0.9),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    const SizedBox(height: 16),

                    // ── 2. ALBUM LIÉ AU SON (si disponible) ──
                    if (_albumTitle.isNotEmpty) ...[
                      Text(
                        "ALBUM LIÉ",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _albumId != null ? _navigateToAlbum : null,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withOpacity(0.09)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 46,
                                  height: 46,
                                  child: SonoritizArtwork(
                                    imageUrl: _albumCover,
                                    width: 46,
                                    height: 46,
                                    borderRadius: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _albumTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _albumYear.isNotEmpty ? "Album • $_albumYear" : "Album",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_albumId != null)
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withOpacity(0.5),
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // ── 3. ARTISTE(S) LIÉ(S) AU SON + BOUTON SUIVRE ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _artists.length > 1 ? "ARTISTES CRÉDITÉS" : "ARTISTE",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Maintenez ou appuyez sur le nom d'un artiste pour ouvrir sa page",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ..._artists.asMap().entries.map((entry) {
                      final index = entry.key;
                      final artist = entry.value;
                      final String name = (artist['name'] ?? '').toString();
                      final String role = (artist['role'] ?? 'Artiste').toString();
                      final String picture = (artist['picture_xl'] ?? '').toString();
                      final int nbFan = (artist['nb_fan'] ?? 0) as int;
                      final bool isFollowed = StorageService().isArtistFollowed(name);
                      final bool isPressed = _pressedArtistIndex == index;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTapDown: (_) => setState(() => _pressedArtistIndex = index),
                          onTapUp: (_) => setState(() => _pressedArtistIndex = null),
                          onTapCancel: () => setState(() => _pressedArtistIndex = null),
                          onLongPress: () => _navigateToArtist(name),
                          onTap: () => _navigateToArtist(name),
                          child: AnimatedScale(
                            scale: isPressed ? 0.96 : 1.0,
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutBack,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Photo de l'artiste
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.45),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: picture.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: picture,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => _buildArtistInitial(name),
                                            )
                                          : _buildArtistInitial(name),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Nom & Rôle / Fans
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          nbFan > 0
                                              ? "$role • ${_formatFans(nbFan)} fans"
                                              : role,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.62),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Bouton Suivre / Suivi
                                  GestureDetector(
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      await StorageService().toggleFollowArtist(name);
                                      if (mounted) setState(() {});
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isFollowed
                                            ? AppColors.primary
                                            : Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isFollowed
                                              ? AppColors.primary
                                              : Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                        child: Text(
                                          isFollowed ? "Suivi" : "Suivre",
                                          style: TextStyle(
                                            color: isFollowed
                                                ? Colors.black
                                                : Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtistInitial(String name) {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
