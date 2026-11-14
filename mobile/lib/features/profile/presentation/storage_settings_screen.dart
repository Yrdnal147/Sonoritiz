import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sonoritiz_dynamic_background.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../offline/presentation/cubit/download_cubit.dart';

/// Écran Stockage & Mémoire Sonoritiz.
/// Reprend l'architecture ouverte et épurée de Profil : chiffres lisibles,
/// barre fine sans lueur et lignes séparées par des filets discrets.
class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  final StorageService _storage = StorageService();

  int _localFilesCount = 0;
  int _searchHistoryCount = 0;
  double _realCacheMb = 0.0;
  bool _isLoadingCache = true;

  @override
  void initState() {
    super.initState();
    _refreshCounts();
    _calculateRealCacheSize();
  }

  void _refreshCounts() {
    setState(() {
      _localFilesCount = _storage.getLocalFiles().length;
      _searchHistoryCount = _storage.getSearchHistory().length;
    });
  }

  Future<void> _calculateRealCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: true, followLinks: false);
        for (final f in files) {
          if (f is File) {
            totalBytes += await f.length();
          }
        }
      }
      if (mounted) {
        setState(() {
          _realCacheMb = (totalBytes / (1024 * 1024)).clamp(0.5, 5000.0);
          _isLoadingCache = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _realCacheMb = 12.0;
          _isLoadingCache = false;
        });
      }
    }
  }

  Future<void> _clearImageCache() async {
    HapticFeedback.mediumImpact();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: false);
        for (final f in files) {
          try {
            await f.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}

    setState(() => _realCacheMb = 0.5);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1A1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cache des pochettes et métadonnées libéré.',
                style: TextStyle(color: Colors.white, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearSearchHistory() async {
    HapticFeedback.selectionClick();
    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildConfirmSheet(
        ctx,
        icon: Icons.history_rounded,
        title: "Effacer l'historique de recherche ?",
        description: _searchHistoryCount > 0
            ? 'Vos $_searchHistoryCount recherches récentes enregistrées seront supprimées.'
            : 'Vos recherches récentes enregistrées seront supprimées.',
        confirmLabel: "Effacer",
        isDestructive: false,
      ),
    );

    if (confirm == true) {
      await _storage.clearSearchHistory();
      _refreshCounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1A1A1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: const Text(
            'Historique de recherche effacé.',
            style: TextStyle(color: Colors.white, fontSize: 13.5),
          ),
        ),
      );
    }
  }

  Future<void> _confirmClearDownloads(List<String> downloadedIds) async {
    if (downloadedIds.isEmpty) return;
    HapticFeedback.selectionClick();

    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildConfirmSheet(
        ctx,
        icon: Icons.delete_outline_rounded,
        title: 'Supprimer les téléchargements ?',
        description:
            'Les ${downloadedIds.length} morceaux stockés hors-ligne seront retirés de la mémoire locale.',
        confirmLabel: 'Supprimer tout',
        isDestructive: true,
      ),
    );

    if (confirm == true && mounted) {
      final dlCubit = context.read<DownloadCubit>();
      for (final id in List<String>.from(downloadedIds)) {
        await dlCubit.removeDownload(id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1A1A1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: const Text(
            'Téléchargements hors-ligne supprimés.',
            style: TextStyle(color: Colors.white, fontSize: 13.5),
          ),
        ),
      );
    }
  }

  Widget _buildConfirmSheet(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String description,
    required String confirmLabel,
    required bool isDestructive,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              icon,
              color: isDestructive ? Colors.redAccent : AppColors.primary,
              size: 30,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDestructive ? Colors.redAccent : AppColors.primary,
                      foregroundColor:
                          isDestructive ? Colors.white : Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SonoritizDynamicBackground(
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<DownloadCubit, DownloadState>(
            builder: (context, dlState) {
              final downloadedIds = dlState is DownloadStateData
                  ? dlState.downloadedIds
                  : <String>[];
              final int offlineCount = downloadedIds.length;

              final double offlineMb = offlineCount * 4.6;
              final double localMb = _localFilesCount * 4.2;
              final double cacheMb = _realCacheMb;
              final double totalMb = offlineMb + localMb + cacheMb;

              final double safeTotal = totalMb > 0.1 ? totalMb : 1.0;
              final int offlineFlex =
                  ((offlineMb / safeTotal) * 100).round().clamp(1, 100);
              final int localFlex =
                  ((localMb / safeTotal) * 100).round().clamp(1, 100);
              final int cacheFlex =
                  ((cacheMb / safeTotal) * 100).round().clamp(1, 100);

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: SonoritizPageTitle(
                              title: 'Stockage & Mémoire',
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 1. Synthèse ouverte du stockage
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MÉMOIRE OCCUPÉE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.42),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                totalMb.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Mo',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Barre horizontale sobre sans ombre néon
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 6,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: offlineFlex,
                                    child: Container(
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    flex: localFlex,
                                    child: Container(
                                      color: Colors.white.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    flex: cacheFlex,
                                    child: Container(color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildBreakdownRow(
                            dotColor: Colors.white.withValues(alpha: 0.85),
                            title: 'Morceaux hors-ligne',
                            subtitle:
                                '$offlineCount titre${offlineCount > 1 ? 's' : ''} téléchargé${offlineCount > 1 ? 's' : ''}',
                            value: '${offlineMb.toStringAsFixed(1)} Mo',
                          ),
                          _subtleDivider(),
                          _buildBreakdownRow(
                            dotColor: Colors.white.withValues(alpha: 0.35),
                            title: 'Fichiers audio locaux',
                            subtitle:
                                '$_localFilesCount titre${_localFilesCount > 1 ? 's' : ''} sur l’appareil',
                            value: '${localMb.toStringAsFixed(1)} Mo',
                          ),
                          _subtleDivider(),
                          _buildBreakdownRow(
                            dotColor: AppColors.primary,
                            title: 'Cache pochettes & données',
                            subtitle: _isLoadingCache
                                ? 'Calcul en cours...'
                                : 'Images et métadonnées temporaires',
                            value: '${cacheMb.toStringAsFixed(1)} Mo',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Actions de gestion (style liste Profil)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 4, 24, 180 + bottomInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gestion des données',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildActionRow(
                            icon: Icons.cached_rounded,
                            title: 'Vider le cache d’images',
                            subtitle:
                                'Libère les fichiers temporaires sans toucher aux titres téléchargés.',
                            onTap: _clearImageCache,
                          ),
                          _subtleDivider(),
                          _buildActionRow(
                            icon: Icons.history_rounded,
                            title: 'Effacer l’historique de recherche',
                            subtitle: _searchHistoryCount > 0
                                ? '$_searchHistoryCount recherche${_searchHistoryCount > 1 ? 's' : ''} récente${_searchHistoryCount > 1 ? 's' : ''}'
                                : 'Aucune recherche enregistrée',
                            onTap: _confirmClearSearchHistory,
                          ),
                          _subtleDivider(),
                          _buildActionRow(
                            icon: Icons.delete_outline_rounded,
                            iconColor: Colors.redAccent,
                            title: 'Supprimer tous les téléchargements',
                            subtitle: offlineCount > 0
                                ? 'Retire les $offlineCount titre${offlineCount > 1 ? 's' : ''} hors-ligne de l’appareil.'
                                : 'Aucun téléchargement enregistré.',
                            onTap: () => _confirmClearDownloads(downloadedIds),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow({
    required Color dotColor,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? Colors.white.withValues(alpha: 0.78),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _subtleDivider() {
    return Divider(
      height: 1,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}
