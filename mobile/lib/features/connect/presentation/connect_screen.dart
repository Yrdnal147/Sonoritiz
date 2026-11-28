import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/sonoritiz_artwork.dart';
import '../../../core/widgets/sonoritiz_dynamic_background.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/player_state.dart';
import '../../player/presentation/screens/lyrics_screen.dart';
import '../data/repositories/connect_repository.dart';
import 'cubit/connect_cubit.dart';
import 'cubit/connect_state.dart';
import 'widgets/connect_music_picker_sheet.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ConnectCubit? existingCubit;
    try {
      existingCubit = BlocProvider.of<ConnectCubit>(context, listen: false);
    } catch (_) {}

    if (existingCubit != null) {
      return const _ConnectScreenBody();
    }

    final storageService = StorageService();
    final apiClient = ApiClient(storageService: storageService);
    final connectRepository = ConnectRepository(apiClient: apiClient);

    return BlocProvider<ConnectCubit>(
      create: (context) => ConnectCubit(
        storageService: storageService,
        repository: connectRepository,
        playerCubit: context.read<PlayerCubit>(),
      ),
      child: const _ConnectScreenBody(),
    );
  }
}

class _ConnectScreenBody extends StatefulWidget {
  const _ConnectScreenBody();

  @override
  State<_ConnectScreenBody> createState() => _ConnectScreenBodyState();
}

class _ConnectScreenBodyState extends State<_ConnectScreenBody> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _joinWithCode() {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length == 6) {
      FocusScope.of(context).unfocus();
      context.read<ConnectCubit>().joinSession(code);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez les 6 caractères du code.')),
      );
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SonoritizDynamicBackground(
      keepWhenPaused: true,
      enableSolarGlow: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 68,
          titleSpacing: AppDimensions.spacingMd,
          title: const SonoritizPageTitle(title: "Connect"),
        ),
        body: BlocListener<ConnectCubit, ConnectState>(
          listener: (context, state) {
            if (state is ConnectError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            } else if (state is ConnectActive && state.actionError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.actionError!),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          child: BlocBuilder<ConnectCubit, ConnectState>(
            builder: (context, state) {
              if (state is ConnectLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                );
              }

              if (state is ConnectActive) {
                return _buildActiveSessionView(context, state);
              }

              return _buildIdleView(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAutoDjPill(BuildContext context, ConnectActive state) {
    final bool enabled = state.autoDjEnabled;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<ConnectCubit>().toggleAutoDj();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 13,
              color: enabled ? Colors.black : AppColors.primary,
            ),
            const SizedBox(width: 5),
            Text(
              enabled ? "Auto-DJ ACTIF" : "Auto-DJ",
              style: TextStyle(
                color: enabled ? Colors.black : Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlayingPreview({ConnectActive? activeState}) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      buildWhen: (prev, cur) =>
          prev.currentTrack != cur.currentTrack ||
          prev.isPlaying != cur.isPlaying ||
          prev.isBuffering != cur.isBuffering,
      builder: (context, playerState) {
        final track = playerState.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final bool isBuffering = playerState.isBuffering;
        final String statusText = isBuffering
            ? "Synchronisation…"
            : (playerState.isPlaying ? "En direct" : "En pause");

        return Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF16161A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.28),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "EN ÉCOUTE DANS LE SALON",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.50),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    if (activeState != null && activeState.isHost)
                      _buildAutoDjPill(context, activeState),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SonoritizArtwork(
                      imageUrl: track.coverUrl,
                      width: 56,
                      height: 56,
                      borderRadius: 12,
                      cacheMaxDimension: 160,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isBuffering)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: AppColors.primary,
                              ),
                            )
                          else
                            Icon(
                              playerState.isPlaying
                                  ? Icons.graphic_eq_rounded
                                  : Icons.pause_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          const SizedBox(width: 5),
                          Text(
                            statusText,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Ligne de paroles synchronisée en direct dans le salon Connect
                BlocSelector<PlayerCubit, PlayerState, String?>(
                  selector: (pState) {
                    final lyrics = pState.currentLyrics;
                    final lines = lyrics?.parsedSyncedLyrics;
                    if (lyrics == null ||
                        !lyrics.hasSynced ||
                        lines == null ||
                        lines.isEmpty) {
                      return null;
                    }
                    final effectivePos = pState.position;
                    for (int i = lines.length - 1; i >= 0; i--) {
                      if (effectivePos >= lines[i].time) {
                        final text = lines[i].text.trim();
                        return text.isNotEmpty ? text : null;
                      }
                    }
                    return null;
                  },
                  builder: (context, activeLyricLine) {
                    if (activeLyricLine == null || activeLyricLine.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LyricsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lyrics_rounded,
                                color: AppColors.primary,
                                size: 15,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: Text(
                                    "« $activeLyricLine »",
                                    key: ValueKey(activeLyricLine),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.8,
                                      fontWeight: FontWeight.w700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.open_in_full_rounded,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIdleView(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Écoutez ensemble,\nen temps réel.",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Lancez un salon d'écoute synchronisé jusqu'à 20 participants ou rejoignez celui d'un ami avec son code à 6 caractères.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),

          _buildNowPlayingPreview(),

          GestureDetector(
            onTap: () => context.read<ConnectCubit>().createSession(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.wifi_tethering_rounded,
                    color: Colors.black,
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Créer une session d'écoute",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Partagez vos playlists, albums et sons en direct",
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.black,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            "REJOINDRE UNE SESSION",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _joinWithCode(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      hintText: "CODE (EX: X8K2P9)",
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _joinWithCode,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "Rejoindre",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget(
    String rawAvatar,
    String initial, {
    double size = 54,
  }) {
    Widget fallback() {
      return Container(
        width: size,
        height: size,
        color: const Color(0xFF1E1E24),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (rawAvatar.isEmpty) return fallback();

    if (rawAvatar.startsWith('data:image/')) {
      try {
        final commaIdx = rawAvatar.indexOf(',');
        if (commaIdx != -1) {
          final b64 = rawAvatar.substring(commaIdx + 1);
          final Uint8List bytes = base64Decode(b64);
          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          );
        }
      } catch (_) {
        return fallback();
      }
    }

    if (rawAvatar.startsWith('http://') || rawAvatar.startsWith('https://')) {
      return SonoritizArtwork(
        imageUrl: rawAvatar,
        width: size,
        height: size,
        borderRadius: size / 2,
        fit: BoxFit.cover,
      );
    }

    if (!kIsWeb) {
      try {
        final cleanPath = rawAvatar.replaceFirst('file://', '');
        final file = File(cleanPath);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          );
        }
      } catch (_) {}
    }

    return fallback();
  }

  Widget _buildActiveSessionView(BuildContext context, ConnectActive state) {
    const List<String> reactionEmojis = ['🔥', '❤️', '👏', '😍', '⚡'];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ConnectionStatus(
                  status: state.connectionStatus,
                  onRetry: () => context.read<ConnectCubit>().reconnect(),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  state.isHost ? "Hôte du salon" : "Invité",
                  style: TextStyle(
                    color: state.isHost
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.78),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Titre synchronisé en direct
          _buildNowPlayingPreview(activeState: state),

          // Bouton principal ADN Sonoritiz : lancer (Hôte) ou suggérer (Invité) une playlist / un album / un son
          _buildMusicPickerBanner(context, state),
          const SizedBox(height: 24),

          // Fil des threads de suggestions (ordonnés par priorité : votes > round-robin > arrivée)
          if (state.suggestionThreads.isNotEmpty) ...[
            _buildSuggestionThreadsSection(context, state),
            const SizedBox(height: 26),
          ],

          // Playlist partagée du salon visible par l'hôte et tous les participants
          if (state.sharedQueue.isNotEmpty) ...[
            _buildSharedSalonPlaylistSection(context, state),
            const SizedBox(height: 28),
          ],

          // Participants avec leur vraie photo de profil et capacité simultanée
          Text(
            "PARTICIPANTS (${state.participants.length}/${state.maxParticipants})",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: state.participants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final p = state.participants[index];
                final username = (p['username'] ?? 'Auditeur').toString();
                final rawAvatar = (p['avatar'] ?? '').toString().trim();
                final isParticipantHost = p['is_host'] == true || index == 0;
                final initial = username.trim().isEmpty
                    ? 'A'
                    : username.trim()[0].toUpperCase();

                return SizedBox(
                  width: 68,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isParticipantHost
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.24),
                                width: isParticipantHost ? 2.0 : 1.2,
                              ),
                            ),
                            child: ClipOval(
                              child: _buildAvatarWidget(rawAvatar, initial),
                            ),
                          ),
                          if (isParticipantHost)
                            Positioned(
                              left: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.stars_rounded,
                                  color: Colors.black,
                                  size: 11,
                                ),
                              ),
                            ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                          fontWeight: isParticipantHost
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Code d'invitation + Copier + Inviter
          Text(
            "CODE D'INVITATION",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.inviteCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: state.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Code d'invitation copié !")),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, color: Colors.black, size: 15),
                        SizedBox(width: 5),
                        Text(
                          "Copier",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Share.share(
                      "Rejoins mon salon d'écoute en direct sur Sonoritiz Connect avec le code : ${state.inviteCode} 🎧",
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_rounded, color: Colors.black, size: 15),
                        SizedBox(width: 5),
                        Text(
                          "Inviter",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // Barre de réactions en direct
          Text(
            "RÉAGIR EN DIRECT",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: reactionEmojis.map((emoji) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.read<ConnectCubit>().sendReaction(emoji);
                },
                child: Container(
                  width: 54,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 21),
                  ),
                ),
              );
            }).toList(),
          ),

          if (state.reactions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.reactions.reversed.take(5).map((r) {
                final emoji = (r['emoji'] ?? '🔥').toString();
                final user = (r['username'] ?? 'Auditeur').toString();
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Text(
                    "$emoji $user",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 30),
          GestureDetector(
            onTap: () => context.read<ConnectCubit>().leaveSession(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                "Quitter la session",
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicPickerBanner(BuildContext context, ConnectActive state) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ConnectMusicPickerSheet.show(context, isHost: state.isHost);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.20),
              const Color(0xFF16161C),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.42),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                state.isHost
                    ? Icons.library_music_rounded
                    : Icons.auto_awesome_rounded,
                color: Colors.black,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.isHost
                        ? "Choisir une playlist, un album ou un son"
                        : "Suggérer un son, un album ou une playlist",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    state.isHost
                        ? "Créez une playlist ou recherchez dans tout le catalogue"
                        : "Envoyez votre suggestion sur l'écran de l'hôte",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionThreadsSection(
    BuildContext context,
    ConnectActive state,
  ) {
    final threads = state.suggestionThreads;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.forum_rounded,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "SUGGESTIONS PAR ORDRE DE PRIORITÉ (${threads.length})",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            if (state.isHost) _buildAutoDjPill(context, state),
          ],
        ),
        const SizedBox(height: 11),
        ...List.generate(threads.length, (idx) {
          final thread = threads[idx];
          final String sid = (thread['id'] ?? '').toString();
          final String kind = (thread['kind'] ?? 'track').toString();
          final String username =
              (thread['username'] ?? 'Un participant').toString();
          final String userAvatar =
              (thread['user_avatar'] ?? '').toString().trim();
          final String defaultLabel = kind == 'album'
              ? "$username a suggéré cet album"
              : (kind == 'playlist'
                  ? "$username a suggéré cette playlist"
                  : "$username a suggéré ce son");
          final String label =
              (thread['label'] ?? defaultLabel).toString().trim();
          final String title = (thread['title'] ?? 'Suggestion').toString();
          final String subtitle = (thread['subtitle'] ?? '').toString();
          final String coverUrl = (thread['cover_url'] ?? '').toString();
          final int votes = thread['votes_count'] is int
              ? thread['votes_count'] as int
              : int.tryParse((thread['votes_count'] ?? '1').toString()) ?? 1;
          final int rank = thread['priority_rank'] is int
              ? thread['priority_rank'] as int
              : (idx + 1);
          final bool isTopPriority = rank == 1;
          final String kindBadge = kind == 'album'
              ? 'ALBUM'
              : (kind == 'playlist' ? 'PLAYLIST' : 'SON');
          final String initial = username.trim().isEmpty
              ? 'P'
              : username.trim()[0].toUpperCase();

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF16161C),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isTopPriority
                      ? AppColors.primary.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.10),
                  width: isTopPriority ? 1.2 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête du thread : rang de priorité + photo + "[Nom] a suggéré ce son / cet album / cette playlist"
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isTopPriority
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "#$rank",
                          style: TextStyle(
                            color: isTopPriority ? Colors.black : Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ClipOval(
                        child: _buildAvatarWidget(
                          userAvatar,
                          initial,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (votes > 1 || state.participants.length > 2)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "🔥 $votes",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 11),

                  // Contenu suggéré (Pochette + Titre + Badge type)
                  Row(
                    children: [
                      SonoritizArtwork(
                        imageUrl: coverUrl,
                        width: 48,
                        height: 48,
                        borderRadius: 10,
                        cacheMaxDimension: 140,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    kindBadge,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.78),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.58),
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Actions Hôte vs Invité (soutien de priorité multi-utilisateurs)
                  if (state.isHost)
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              context
                                  .read<ConnectCubit>()
                                  .hostAcceptSuggestionNow(thread);
                            },
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Lancer",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context
                                  .read<ConnectCubit>()
                                  .hostQueueSuggestionNext(thread);
                            },
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.playlist_add_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    "Lire ensuite",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => context
                              .read<ConnectCubit>()
                              .hostDismissSuggestion(sid),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white.withValues(alpha: 0.65),
                              size: 17,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.read<ConnectCubit>().upvoteSuggestion(sid);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            "🔥 Soutenir (+1 priorité)",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSharedSalonPlaylistSection(
    BuildContext context,
    ConnectActive state,
  ) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      buildWhen: (prev, cur) =>
          prev.currentTrack?.id != cur.currentTrack?.id ||
          prev.isPlaying != cur.isPlaying,
      builder: (context, playerState) {
        final activeTrackId = playerState.currentTrack?.id;
        final tracks = state.sharedQueue;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.queue_music_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    "PLAYLIST DU SALON • ${state.sharedPlaylistTitle.toUpperCase()}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Text(
                  "${tracks.length} titres",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (!state.isHost) ...[
              const SizedBox(height: 4),
              Text(
                "Touchez un titre pour le suggérer directement à l'hôte.",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11.5,
                ),
              ),
            ],
            const SizedBox(height: 11),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15151A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: tracks.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 14,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                itemBuilder: (context, index) {
                  final TrackModel t = tracks[index];
                  final bool isCurrent = t.id == activeTrackId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (state.isHost) {
                        context.read<ConnectCubit>().hostJumpToSharedTrack(t);
                      } else if (!isCurrent) {
                        context.read<ConnectCubit>().suggestTrack(t);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "« ${t.title} » a été suggéré à l'hôte !",
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      color: isCurrent
                          ? AppColors.primary.withValues(alpha: 0.11)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          SonoritizArtwork(
                            imageUrl: t.coverUrl,
                            width: 44,
                            height: 44,
                            borderRadius: 9,
                            cacheMaxDimension: 130,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrent
                                        ? AppColors.primary
                                        : Colors.white,
                                    fontSize: 13.8,
                                    fontWeight: isCurrent
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.56),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isCurrent)
                            Icon(
                              playerState.isPlaying
                                  ? Icons.graphic_eq_rounded
                                  : Icons.pause_circle_filled_rounded,
                              color: AppColors.primary,
                              size: 19,
                            )
                          else if (!state.isHost)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "Suggérer",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            Text(
                              _formatDuration(t.durationSeconds),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.42),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  final String status;
  final VoidCallback onRetry;

  const _ConnectionStatus({required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final connected = status == 'connected';
    final label = connected
        ? 'Synchronisé en temps réel'
        : status == 'connecting'
            ? 'Connexion à la session…'
            : 'Connexion interrompue';
    final color = connected ? AppColors.success : AppColors.error;

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connected
                  ? Icons.wifi_rounded
                  : status == 'connecting'
                      ? Icons.sync_rounded
                      : Icons.wifi_off_rounded,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!connected && status != 'connecting') ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: color,
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
