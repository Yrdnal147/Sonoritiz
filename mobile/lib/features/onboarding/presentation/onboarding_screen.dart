import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/artists_data.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sonoritiz_brand_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _ambientController;
  late final List<String> _featuredCovers;

  static const List<_OnboardingSlideData> _slides = [
    _OnboardingSlideData(
      titlePrefix: 'Vivez la musique ',
      titleAccent: 'sans limites',
      subtitle:
          'Lecteur immersif, égaliseur studio et recommandations façonnées uniquement selon vos écoutes et vos artistes.',
      badge: 'Sonoritiz Studio Audio',
      accentIcon: Icons.graphic_eq_rounded,
    ),
    _OnboardingSlideData(
      titlePrefix: 'Explorez par ',
      titleAccent: 'émotions & paroles',
      subtitle:
          'Sélectionnez vos émotions avec Sonoritiz Moods, chantez en karaoké synchronisé et vibrez sur chaque refrain.',
      badge: 'Moods & Karaoké Live',
      accentIcon: Icons.auto_awesome_rounded,
    ),
    _OnboardingSlideData(
      titlePrefix: 'Emportez votre ',
      titleAccent: 'univers partout',
      subtitle:
          'Téléchargez vos titres hors-ligne, plongez dans les Shorts musicaux et écoutez vos podcasts sur un même espace.',
      badge: 'Hors-Ligne • Shorts • Podcasts',
      accentIcon: Icons.offline_bolt_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _featuredCovers = ArtistsData.globalArtists
        .map((a) => (a['imageUrl'] ?? '').trim())
        .where((url) => url.startsWith('http'))
        .take(18)
        .toList();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await StorageService().setAppOnboardingCompleted(true);
    if (!mounted) return;
    context.go('/welcome');
  }

  void _nextSlide() {
    if (_currentPage < _slides.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      unawaited(_completeOnboarding());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // En-tête discret avec petit logo + bouton Passer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Row(
                children: [
                  const SonoritizVectorLogo(
                    size: 32,
                    variant: SonoritizLogoVariant.standard,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Sonoritiz',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  if (!isLast)
                    TextButton(
                      onPressed: _completeOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: const Text(
                        'Passer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Carrousel des 3 pages d'onboarding
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return _OnboardingSlideView(
                    slide: slide,
                    slideIndex: index,
                    covers: _featuredCovers,
                    ambientAnimation: _ambientController,
                  );
                },
              ),
            ),

            // Barre de progression + Bouton suivant orange (icône/texte NOIR)
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 8, 26, 24),
              child: Row(
                children: [
                  Row(
                    children: List.generate(_slides.length, (idx) {
                      final active = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.only(right: 8),
                        height: 6,
                        width: active ? 28 : 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  if (!isLast)
                    GestureDetector(
                      onTap: _nextSlide,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.black,
                          size: 26,
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _completeOnboarding,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Commencer',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.black,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlideData {
  final String titlePrefix;
  final String titleAccent;
  final String subtitle;
  final String badge;
  final IconData accentIcon;

  const _OnboardingSlideData({
    required this.titlePrefix,
    required this.titleAccent,
    required this.subtitle,
    required this.badge,
    required this.accentIcon,
  });
}

class _OnboardingSlideView extends StatelessWidget {
  final _OnboardingSlideData slide;
  final int slideIndex;
  final List<String> covers;
  final Animation<double> ambientAnimation;

  const _OnboardingSlideView({
    required this.slide,
    required this.slideIndex,
    required this.covers,
    required this.ambientAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone supérieure : mosaïque dynamique de pochettes d'artistes mondiaux + carte signature
          Expanded(
            flex: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E12),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _GlobalArtistCoversCollage(
                      covers: covers,
                      slideOffset: slideIndex * 6,
                      ambientAnimation: ambientAnimation,
                    ),

                    // Dégradé sombre subtil pour garder les pochettes visibles et le premier plan lisible
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.28),
                            Colors.black.withValues(alpha: 0.56),
                            Colors.black.withValues(alpha: 0.90),
                          ],
                        ),
                      ),
                    ),

                    // Élément vectoriel signature propre au slide
                    Center(
                      child: _SlideSignatureCard(
                        slideIndex: slideIndex,
                        slide: slide,
                        covers: covers,
                        ambientAnimation: ambientAnimation,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Badge discret
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(slide.accentIcon, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    slide.badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Grand titre bicolore (blanc + orange Sonoritiz)
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 31,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -0.7,
              ),
              children: [
                TextSpan(text: slide.titlePrefix),
                TextSpan(
                  text: slide.titleAccent,
                  style: const TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Phrase descriptive authentique
          Text(
            slide.subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _GlobalArtistCoversCollage extends StatelessWidget {
  final List<String> covers;
  final int slideOffset;
  final Animation<double> ambientAnimation;

  const _GlobalArtistCoversCollage({
    required this.covers,
    required this.slideOffset,
    required this.ambientAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ambientAnimation,
      builder: (context, _) {
        final double shift = (ambientAnimation.value - 0.5) * 14.0;
        return Transform.translate(
          offset: Offset(shift, -shift * 0.4),
          child: Transform.rotate(
            angle: -0.07,
            child: Transform.scale(
              scale: 1.16,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(6),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: 9,
                itemBuilder: (context, idx) {
                  final url = covers.isEmpty
                      ? ''
                      : covers[(idx + slideOffset) % covers.length];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: const Color(0xFF1B1B22),
                      child: url.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Center(
                                child: SonoritizVectorLogo(
                                  size: 28,
                                  opacity: 0.35,
                                  variant: SonoritizLogoVariant.allWhite,
                                ),
                              ),
                            )
                          : const Center(
                              child: SonoritizVectorLogo(
                                size: 28,
                                opacity: 0.35,
                                variant: SonoritizLogoVariant.allWhite,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlideSignatureCard extends StatelessWidget {
  final int slideIndex;
  final _OnboardingSlideData slide;
  final List<String> covers;
  final Animation<double> ambientAnimation;

  const _SlideSignatureCard({
    required this.slideIndex,
    required this.slide,
    required this.covers,
    required this.ambientAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ambientAnimation,
      builder: (context, _) {
        final double floatY = math.sin(ambientAnimation.value * math.pi) * 6.0;
        return Transform.translate(
          offset: Offset(0, floatY),
          child: Container(
            width: 245,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF111116).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (slideIndex == 0) ...[
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFF1F1F26),
                          child: covers.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: covers.first,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.music_note_rounded,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.music_note_rounded,
                                  color: AppColors.primary,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lecture Hi-Res',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Mix créé selon vos écoutes',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Barre de progression simulée orange
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.35 + (ambientAnimation.value * 0.45),
                      minHeight: 5,
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ] else if (slideIndex == 1) ...[
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _MiniEmotionPill(
                        label: 'Joie',
                        color: Color(0xFFFFC83D),
                        selected: false,
                      ),
                      _MiniEmotionPill(
                        label: 'L’amour',
                        color: AppColors.primary,
                        selected: true,
                      ),
                      _MiniEmotionPill(
                        label: 'Sérénité',
                        color: Color(0xFF4ECDC4),
                        selected: false,
                      ),
                      _MiniEmotionPill(
                        label: 'Nostalgie',
                        color: AppColors.primary,
                        selected: true,
                      ),
                      _MiniEmotionPill(
                        label: 'Espoir',
                        color: AppColors.primary,
                        selected: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Paroles synchronisées & Moods',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  const SonoritizVectorLogo(
                    size: 54,
                    variant: SonoritizLogoVariant.standard,
                  ),
                  const SizedBox(height: 12),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _MiniFeatureChip(
                        icon: Icons.download_done_rounded,
                        label: 'Hors-ligne',
                      ),
                      _MiniFeatureChip(
                        icon: Icons.play_circle_outline_rounded,
                        label: 'Shorts',
                      ),
                      _MiniFeatureChip(
                        icon: Icons.podcasts_rounded,
                        label: 'Podcasts',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniEmotionPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;

  const _MiniEmotionPill({
    required this.label,
    required this.color,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.primary : color.withValues(alpha: 0.70),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniFeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniFeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.black, size: 18),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
