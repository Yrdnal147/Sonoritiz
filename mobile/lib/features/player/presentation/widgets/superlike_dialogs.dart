import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/superlike_torch_badge.dart';
import '../../data/models/track_model.dart';
import '../cubit/superlike_cubit.dart';

class SuperlikeDialogs {
  /// 1. Boîte de dialogue d'avertissement de limite (20/20)
  static Future<void> showLimitDialog({
    required BuildContext context,
    required TrackModel newTrack,
    required VoidCallback onReplaced,
  }) async {
    final storage = StorageService();
    final rawUsername = storage.username;
    final username = rawUsername.isNotEmpty ? rawUsername : "Mélomane";

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF151010),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: const Color(0xFFFF9100).withOpacity(0.55),
            width: 1.4,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône flambeau étincelant au sommet
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0x55FF6D00),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFFFD600).withOpacity(0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF3D00).withOpacity(0.35),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: SuperlikeTorchBadge(
                  size: TorchBadgeSize.large,
                  showBackground: false,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Sonoritiz Superlike",
              style: TextStyle(
                color: Color(0xFFFFD600),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "$username, veux-tu ajouter un Superlike à ce son ? Si tu le fais, tu retireras un son dans ta prestigieuse Sonoritiz Superlike.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: newTrack.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: newTrack.coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.music_note,
                                color: Colors.white38,
                                size: 18,
                              ),
                            )
                          : const Icon(
                              Icons.music_note,
                              color: Colors.white38,
                              size: 18,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          newTrack.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          newTrack.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.white.withOpacity(0.25)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Annuler",
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF1744),
                          Color(0xFFFF6D00),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3D00).withOpacity(0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        showReplacementSheet(
                          context: context,
                          newTrack: newTrack,
                          onReplaced: onReplaced,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Continuer",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 2. Feuille modale des 12 morceaux Superlikés à remplacer
  static Future<void> showReplacementSheet({
    required BuildContext context,
    required TrackModel newTrack,
    required VoidCallback onReplaced,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _SuperlikeReplacementSheetWidget(
        newTrack: newTrack,
        onReplaced: onReplaced,
      ),
    );
  }

  /// 3. Confirmation de retrait du son choisi
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required TrackModel trackToRemove,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1210),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: const Color(0xFFFF9100).withOpacity(0.4),
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            const SuperlikeTorchBadge(
              size: TorchBadgeSize.small,
              showBackground: false,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Confirmation",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Es-tu sûr de retirer le son \"${trackToRemove.title}\" de ${trackToRemove.artistName} dans tes Superlikes ?",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx, false),
            child: const Text(
              "Non",
              style: TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(confirmCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3D00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              "Remplacer",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuperlikeReplacementSheetWidget extends StatefulWidget {
  final TrackModel newTrack;
  final VoidCallback onReplaced;

  const _SuperlikeReplacementSheetWidget({
    Key? key,
    required this.newTrack,
    required this.onReplaced,
  }) : super(key: key);

  @override
  State<_SuperlikeReplacementSheetWidget> createState() =>
      _SuperlikeReplacementSheetWidgetState();
}

class _SuperlikeReplacementSheetWidgetState
    extends State<_SuperlikeReplacementSheetWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SuperlikeCubit>();
    final superlikes = cubit.state.tracks;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF100B09),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0xFFFF9100), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // En-tête : Flambeau étincelant avec animation
          AnimatedBuilder(
            animation: _sparkleController,
            builder: (context, child) {
              final scale = 1.0 + (_sparkleController.value * 0.12);
              final glow = 16.0 + (_sparkleController.value * 18.0);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3D00).withOpacity(0.6),
                          blurRadius: glow,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFFEA00).withOpacity(0.4),
                          blurRadius: glow * 1.5,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: scale,
                    child: const SuperlikeTorchBadge(
                      size: TorchBadgeSize.large,
                      showBackground: true,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            "Sonoritiz Superlike",
            style: TextStyle(
              color: Color(0xFFFFD600),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              "Sélectionnez le son à retirer pour accueillir le nouveau chef-d'œuvre (20/20)",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),

          // Liste des 12 sons classés et bien cadrés
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              physics: const BouncingScrollPhysics(),
              itemCount: superlikes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final track = superlikes[index];
                final rank = index + 1;

                return InkWell(
                  onTap: () async {
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final confirmed = await SuperlikeDialogs.showConfirmDialog(
                      context: context,
                      trackToRemove: track,
                    );
                    if (confirmed == true && mounted) {
                      await cubit.replaceSuperlike(
                        oldTrack: track,
                        newTrack: widget.newTrack,
                      );
                      if (mounted) {
                        nav.pop(); // Close sheet
                        widget.onReplaced();
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF1E140F),
                            behavior: SnackBarBehavior.floating,
                            content: Row(
                              children: [
                                const SuperlikeTorchBadge(
                                  size: TorchBadgeSize.small,
                                  showBackground: false,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "\"${widget.newTrack.title}\" a remplacé \"${track.title}\" dans vos Superlikes !",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFF9100).withOpacity(0.22),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Numéro de classement (#01 ... #12)
                        Container(
                          width: 32,
                          alignment: Alignment.center,
                          child: Text(
                            "#$rank",
                            style: const TextStyle(
                              color: Color(0xFFFFD600),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Pochette avec badge flambeau
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: track.coverUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: track.coverUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          color: AppColors.surfaceLight,
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white38,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: AppColors.surfaceLight,
                                        child: const Icon(
                                          Icons.music_note,
                                          color: Colors.white38,
                                        ),
                                      ),
                              ),
                              const Positioned(
                                top: 2,
                                right: 2,
                                child: SuperlikeTorchBadge(
                                  size: TorchBadgeSize.small,
                                  showBackground: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Titre & Artiste
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
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                track.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bouton 'Remplacer'
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3D00).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF6D00).withOpacity(0.5),
                              width: 0.9,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_horiz_rounded,
                                color: Color(0xFFFFD600),
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Retirer",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
