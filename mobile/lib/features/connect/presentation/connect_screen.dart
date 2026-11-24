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
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/player_state.dart';
import '../data/repositories/connect_repository.dart';
import 'cubit/connect_cubit.dart';
import 'cubit/connect_state.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Utilise le ConnectCubit global (persistant entre les onglets) s'il est présent,
    // ou en crée un localement pour les tests isolés.
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

  Widget _buildNowPlayingPreview() {
    return BlocBuilder<PlayerCubit, PlayerState>(
      buildWhen: (prev, cur) =>
          prev.currentTrack != cur.currentTrack ||
          prev.isPlaying != cur.isPlaying,
      builder: (context, playerState) {
        final track = playerState.currentTrack;
        if (track == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF16161A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.26),
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
                Text(
                  "EN ÉCOUTE ACTUELLEMENT",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
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
                          Icon(
                            playerState.isPlaying
                                ? Icons.graphic_eq_rounded
                                : Icons.pause_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            playerState.isPlaying ? "En direct" : "En pause",
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIdleView(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
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
            "Lancez un salon d'écoute synchronisé ou rejoignez celui d'un ami avec son code à 6 caractères.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),

          // Aperçu du titre en cours s'il y en a un
          _buildNowPlayingPreview(),

          // 1. Démarrer une session
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
                          "Génère un code instantané à partager",
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

          // 2. Rejoindre directement avec un code (sans popup)
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

  /// Construit la photo de profil d'un participant (Data URI base64, fichier local ou URL réseau).
  Widget _buildParticipantPhoto(
    Map<String, dynamic> participant,
    String initial,
  ) {
    final String rawAvatar = (participant['avatar'] ?? '').toString().trim();

    Widget fallback() {
      return Container(
        width: 54,
        height: 54,
        color: const Color(0xFF1E1E24),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (rawAvatar.isEmpty) {
      return fallback();
    }

    if (rawAvatar.startsWith('data:image/')) {
      try {
        final commaIdx = rawAvatar.indexOf(',');
        if (commaIdx != -1) {
          final b64 = rawAvatar.substring(commaIdx + 1);
          final Uint8List bytes = base64Decode(b64);
          return Image.memory(
            bytes,
            width: 54,
            height: 54,
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
        width: 54,
        height: 54,
        borderRadius: 27,
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
            width: 54,
            height: 54,
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConnectionStatus(
            status: state.connectionStatus,
            onRetry: () => context.read<ConnectCubit>().reconnect(),
          ),
          const SizedBox(height: 24),

          // Titre synchronisé en direct
          _buildNowPlayingPreview(),

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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.5,
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

          const SizedBox(height: 28),

          // Participants avec leur vraie photo de profil
          Text(
            "PARTICIPANTS (${state.participants.length})",
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
                              child: _buildParticipantPhoto(p, initial),
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

          if (!state.isHost) ...[
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () {
                context.read<ConnectCubit>().suggestCurrentTrackToHost();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        "Votre son a été envoyé à la file d'attente de l'hôte !"),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.playlist_add_check_circle_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Suggérer mon son à la file du salon",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
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
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
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
