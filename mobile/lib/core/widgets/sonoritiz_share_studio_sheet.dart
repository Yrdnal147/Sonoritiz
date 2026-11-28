import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/player/data/models/track_model.dart';
import '../services/palette_service.dart';
import '../storage/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/share_card_generator.dart';
import '../utils/share_utils.dart';
import 'sonoritiz_artwork.dart';

enum _ShareStudioMode { track, lyrics }

/// Studio de partage interactif Sonoritiz (inspiré du sélecteur de carte Spotify + ADN Sonoritiz) :
/// - Mode Paroles : Paroles grand format SANS guillemets, "[Artiste] a dit !", vrai logo d'origine orange/blanc,
///   choix de 3 polices (`Matey`, `Fontaine`, `Etna`) et 3 backgrounds (3 couleurs dominantes de la pochette).
/// - Mode Son en cours : Carte flottante avec grande pochette carrée, Titre + Artiste + [Logo d'origine] Sonoritiz,
///   3 couleurs dominantes de la pochette + 4e fond Pochette Floutée + toggle onde acoustique + 3 polices + barre d'envoi rapide.
class SonoritizShareStudioSheet extends StatefulWidget {
  final _ShareStudioMode mode;
  final TrackModel track;
  final List<String> lyricLines;
  final Color? initialDominant;
  final Color? initialAccent;
  final Color? initialDeep;

  const SonoritizShareStudioSheet._({
    required this.mode,
    required this.track,
    this.lyricLines = const [],
    this.initialDominant,
    this.initialAccent,
    this.initialDeep,
  });

  static Future<void> showForTrack(
    BuildContext context, {
    required TrackModel track,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SonoritizShareStudioSheet._(
        mode: _ShareStudioMode.track,
        track: track,
      ),
    );
  }

  static Future<void> showForLyrics(
    BuildContext context, {
    required TrackModel track,
    required List<String> lyricLines,
    Color? dominantColor,
    Color? accentColor,
    Color? deepColor,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SonoritizShareStudioSheet._(
        mode: _ShareStudioMode.lyrics,
        track: track,
        lyricLines: lyricLines,
        initialDominant: dominantColor,
        initialAccent: accentColor,
        initialDeep: deepColor,
      ),
    );
  }

  @override
  State<SonoritizShareStudioSheet> createState() =>
      _SonoritizShareStudioSheetState();
}

class _SonoritizShareStudioSheetState extends State<SonoritizShareStudioSheet> {
  late List<Color> _threeBackgrounds;
  int _selectedBgIndex = 0; // 0, 1, 2 = 3 couleurs dominantes ; 3 = pochette floutée
  SonoritizShareFont _selectedFont = SonoritizShareFont.matey;
  bool _showAcousticWave = true;
  bool _isExporting = false;
  late final bool _isSuperliked;
  late final List<String> _cleanedLyrics;

  @override
  void initState() {
    super.initState();
    _isSuperliked = StorageService()
        .getSuperlikesRaw()
        .any((item) => item['id']?.toString() == widget.track.id);
    _cleanedLyrics = widget.lyricLines
        .map(ShareCardGenerator.cleanLyricLine)
        .where((l) => l.isNotEmpty && l != '♪')
        .take(4)
        .toList();

    final cachedPalette = PaletteService.getCached(widget.track.coverUrl);
    final dom = widget.initialDominant ??
        cachedPalette?.dominantColor ??
        const Color(0xFF3A4454);
    final acc = widget.initialAccent ??
        cachedPalette?.accentColor ??
        const Color(0xFFFA7921);
    final deep = widget.initialDeep ??
        cachedPalette?.deepColor ??
        const Color(0xFF161A22);

    _threeBackgrounds = ShareCardGenerator.buildThreeCoverBackgrounds(
      dominant: dom,
      accent: acc,
      deep: deep,
    );

    if (cachedPalette == null && widget.track.coverUrl.isNotEmpty) {
      PaletteService.getPalette(widget.track.coverUrl).then((p) {
        if (!mounted) return;
        setState(() {
          _threeBackgrounds = ShareCardGenerator.buildThreeCoverBackgrounds(
            dominant: p.dominantColor,
            accent: p.accentColor,
            deep: p.deepColor,
          );
        });
      });
    }
  }

  Color get _activeBgColor =>
      _threeBackgrounds[_selectedBgIndex.clamp(0, _threeBackgrounds.length - 1)];

  bool get _useBlurredCover =>
      widget.mode == _ShareStudioMode.track && _selectedBgIndex == 3;

  Future<void> _handleCopyLink() async {
    HapticFeedback.selectionClick();
    final text = widget.mode == _ShareStudioMode.lyrics
        ? "${_cleanedLyrics.join('\n')}\n\n— ${widget.track.artistName} a dit ! (${widget.track.title})\nhttps://sonoritiz.com/track/${widget.track.id}"
        : ShareUtils.formatShareText(widget.track, isSuperliked: _isSuperliked);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF1A1B22),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        content: Text(
          'Lien et détails copiés dans le presse-papiers !',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _handleShareNow() async {
    if (_isExporting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isExporting = true);
    try {
      if (widget.mode == _ShareStudioMode.lyrics) {
        await ShareUtils.exportAndShareLyricsCard(
          track: widget.track,
          lyricLines: _cleanedLyrics,
          backgroundColor: _activeBgColor,
          deepColor: _threeBackgrounds.last,
          accentColor: _threeBackgrounds[1],
          font: _selectedFont,
        );
      } else {
        await ShareUtils.exportAndShareTrackCard(
          track: widget.track,
          backgroundColor: _activeBgColor,
          useBlurredCoverBackground: _useBlurredCover,
          font: _selectedFont,
          showAcousticWave: _showAcousticWave,
          isSuperliked: _isSuperliked,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final double sheetMaxHeight = media.size.height * 0.92;

    return Container(
      constraints: BoxConstraints(maxHeight: sheetMaxHeight),
      decoration: BoxDecoration(
        color: const Color(0xFF121215),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée supérieure
              Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),

              // 1. Aperçu en direct de la carte (Track ou Lyrics)
              Center(
                child: widget.mode == _ShareStudioMode.lyrics
                    ? _buildLyricsCardLivePreview()
                    : _buildTrackCardLivePreview(),
              ),
              const SizedBox(height: 18),

              // 2. Sélecteur des 3 backgrounds (3 couleurs dominantes de la pochette) + options
              _buildBackgroundSwatchesRow(),
              const SizedBox(height: 16),

              // 3. Sélecteur des 3 polices : Matey • Fontaine • Etna
              _buildFontSelectorRow(),
              const SizedBox(height: 20),

              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.09),
              ),
              const SizedBox(height: 16),

              // 4. Barre d'actions de partage direct (inspirée de l'exemple Spotify)
              _buildBottomShareTargetsRow(),
            ],
          ),
        ),
      ),
    );
  }

  /// Aperçu en direct de la carte du Son en cours (style Spotify + signature Sonoritiz)
  Widget _buildTrackCardLivePreview() {
    final Color bg = _activeBgColor;
    final Color topBg = Color.lerp(bg, Colors.white, 0.08) ?? bg;
    final Color bottomBg =
        Color.lerp(bg, const Color(0xFF0A0A0E), 0.34) ?? bg;
    final Color cardSurface =
        Color.lerp(bg, const Color(0xFF141519), 0.74) ??
            const Color(0xFF1C1D22);
    final Color waveColor = _isSuperliked
        ? const Color(0xFFFFD54F)
        : (Color.lerp(bg, AppColors.primary, 0.55) ?? AppColors.primary);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 268,
      height: 368,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: _useBlurredCover
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topBg, bg, bottomBg],
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_useBlurredCover) ...[
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: SonoritizArtwork(
                imageUrl: widget.track.coverUrl,
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
              ),
            ),
            ColoredBox(color: bg.withValues(alpha: 0.38)),
            ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
          ],
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 208,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.48),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grande pochette carrée en haut de la carte flottante
                  AspectRatio(
                    aspectRatio: 1,
                    child: SonoritizArtwork(
                      imageUrl: widget.track.coverUrl,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 10,
                      cacheMaxDimension: 500,
                    ),
                  ),
                  const SizedBox(height: 11),
                  // Titre avec la police choisie (Matey / Fontaine / Etna)
                  Text(
                    widget.track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _selectedFont.textStyle(
                      fontSize: 14.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Nom de l'artiste
                  Text(
                    widget.track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 11),
                  // Pied de la carte : Vrai logo d'origine + Sonoritiz à gauche | Onde acoustique à droite
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 17,
                          height: 17,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Sonoritiz',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      if (_showAcousticWave)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [5.0, 9.0, 13.0, 8.0, 14.0, 10.0, 6.0]
                              .map(
                                (h) => Container(
                                  width: 2.2,
                                  height: h,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: waveColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Aperçu en direct de la carte Paroles :
  /// - Paroles plus grandes et SANS guillemets
  /// - En bas à gauche : "[Nom d'artiste] a dit !" (sans SONORITIZ ni Paroles...)
  /// - En bas à droite & en filigrane : Vrai logo d'origine de l'application (orange & blanc)
  Widget _buildLyricsCardLivePreview() {
    final Color bg = _activeBgColor;
    final Color topTint = Color.lerp(bg, Colors.white, 0.06) ?? bg;
    final Color midTint =
        Color.lerp(bg, const Color(0xFF0E1017), 0.32) ?? bg;
    final Color bottomTint =
        Color.lerp(bg, const Color(0xFF07080C), 0.58) ?? bg;

    final String joinedLyrics = _cleanedLyrics.isNotEmpty
        ? _cleanedLyrics.join('\n\n')
        : ShareCardGenerator.cleanLyricLine(widget.track.title);

    final double previewFontSize = _cleanedLyrics.length <= 1
        ? 21.0
        : (_cleanedLyrics.length == 2
            ? 18.0
            : (_cleanedLyrics.length == 3 ? 16.0 : 14.5));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 292,
      height: 365,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [topTint, midTint, bottomTint],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.20),
            width: 1.0,
          ),
        ),
        child: Stack(
          children: [
            // Filigrane central du vrai logo d'origine (orange & blanc)
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 0.12,
                  child: Image.asset(
                    'assets/images/app_logo_foreground.png',
                    width: 138,
                    height: 138,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête : Pochette + Titre + Artiste
                Row(
                  children: [
                    SonoritizArtwork(
                      imageUrl: widget.track.coverUrl,
                      width: 40,
                      height: 40,
                      borderRadius: 9,
                      cacheMaxDimension: 140,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                // Paroles au centre : GRAND FORMAT & SANS GUILLEMETS
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          joinedLyrics,
                          style: _selectedFont.textStyle(
                            fontSize: previewFontSize,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 9),
                // Pied : "[Nom d'artiste] a dit !" à gauche + Vrai logo d'origine en bas à droite
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: widget.track.artistName.trim().isNotEmpty
                                  ? widget.track.artistName.trim()
                                  : 'L’artiste',
                              style: _selectedFont.textStyle(
                                fontSize: 12.2,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: ' a dit !',
                              style: _selectedFont.textStyle(
                                fontSize: 12.2,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 0.9,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Rangée des 3 pastilles circulaires des couleurs dominantes de la pochette
  /// (+ option fond flouté et option onde acoustique en mode partage de son)
  Widget _buildBackgroundSwatchesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _threeBackgrounds.length; i++) ...[
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedBgIndex = i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(_threeBackgrounds[i], Colors.white, 0.14) ??
                        _threeBackgrounds[i],
                    _threeBackgrounds[i],
                  ],
                ),
                border: Border.all(
                  color: _selectedBgIndex == i
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.22),
                  width: _selectedBgIndex == i ? 2.6 : 1.2,
                ),
                boxShadow: _selectedBgIndex == i
                    ? [
                        BoxShadow(
                          color: _threeBackgrounds[i].withValues(alpha: 0.55),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
        if (widget.mode == _ShareStudioMode.track) ...[
          // 4e cercle : Fond Pochette Floutée (Idée A)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedBgIndex = 3);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selectedBgIndex == 3
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: _selectedBgIndex == 3
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.22),
                  width: _selectedBgIndex == 3 ? 2.4 : 1.2,
                ),
              ),
              child: const Icon(
                Icons.blur_on_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          // 5e cercle : Activer/désactiver l'onde acoustique (Idée D)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showAcousticWave = !_showAcousticWave);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _showAcousticWave
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: _showAcousticWave
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.20),
                  width: 1.4,
                ),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                color: _showAcousticWave ? AppColors.primary : Colors.white60,
                size: 18,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Sélecteur des 3 polices : Matey • Fontaine • Etna
  Widget _buildFontSelectorRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Aa',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        for (final font in SonoritizShareFont.values) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFont = font);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _selectedFont == font
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _selectedFont == font
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Text(
                  font.label,
                  style: font.textStyle(
                    fontSize: 13.0,
                    color: _selectedFont == font ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Barre d'actions de partage direct (Copier le lien • WhatsApp • Stories • SMS • Statut)
  Widget _buildBottomShareTargetsRow() {
    if (_isExporting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildShareTargetButton(
          label: 'Copier le\nlien',
          icon: Icons.link_rounded,
          backgroundColor: const Color(0xFF282930),
          onTap: _handleCopyLink,
        ),
        _buildShareTargetButton(
          label: 'WhatsApp',
          icon: Icons.chat_bubble_rounded,
          backgroundColor: const Color(0xFF25D366),
          onTap: _handleShareNow,
        ),
        _buildShareTargetButton(
          label: 'Stories',
          icon: Icons.camera_alt_rounded,
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF833AB4),
              Color(0xFFFD1D1D),
              Color(0xFFFCB045),
            ],
          ),
          onTap: _handleShareNow,
        ),
        _buildShareTargetButton(
          label: 'SMS',
          icon: Icons.sms_rounded,
          backgroundColor: const Color(0xFF282930),
          onTap: _handleShareNow,
        ),
        _buildShareTargetButton(
          label: 'Statut',
          icon: Icons.amp_stories_rounded,
          backgroundColor: const Color(0xFF1EBE5D),
          onTap: _handleShareNow,
        ),
      ],
    );
  }

  Widget _buildShareTargetButton({
    required String label,
    required IconData icon,
    Color? backgroundColor,
    Gradient? gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
