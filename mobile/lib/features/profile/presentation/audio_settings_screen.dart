import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sonoritiz_dynamic_background.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';

/// Écran des réglages Audio & Lecture Sonoritiz.
/// Reprend l'architecture ouverte et éditoriale de Profil (typographie nette,
/// séparateurs fins, sans cadres néon ni cartes encadrées superflues).
class AudioSettingsScreen extends StatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  State<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends State<AudioSettingsScreen> {
  final StorageService _storage = StorageService();

  late String _streamingQuality;
  late bool _autoplay;
  late bool _volumeNormalization;
  late String _audioPreset;

  final List<Map<String, dynamic>> _qualityOptions = const [
    {
      'id': 'hifi',
      'title': 'Studio Master / Hi-Fi',
      'description':
          'Fidélité sonore sans perte, idéale au casque ou sur installation Hi-Fi.',
      'badge': 'Lossless',
      'icon': Icons.album_outlined,
    },
    {
      'id': 'haute',
      'title': 'Très haute qualité',
      'description':
          'Son riche, dynamique et détaillé à 320 kbps pour le quotidien.',
      'badge': '320 kbps',
      'icon': Icons.high_quality_outlined,
    },
    {
      'id': 'normale',
      'title': 'Qualité standard',
      'description':
          'Son clair et équilibré à 160 kbps, adapté aux déplacements.',
      'badge': '160 kbps',
      'icon': Icons.speed_rounded,
    },
    {
      'id': 'economie',
      'title': 'Économie de données',
      'description':
          'Compression optimisée à 96 kbps pour préserver votre forfait mobile.',
      'badge': '96 kbps',
      'icon': Icons.data_saver_on_rounded,
    },
  ];

  final List<Map<String, dynamic>> _presets = const [
    {
      'name': 'Studio',
      'desc': 'Rendu plat et fidèle au mixage original.',
      'icon': Icons.equalizer_rounded,
    },
    {
      'name': 'Bass Boost',
      'desc': 'Graves profonds et percutants pour l’Urbain et l’Électro.',
      'icon': Icons.speaker_group_outlined,
    },
    {
      'name': 'Vocal Clair',
      'desc': 'Met en avant les voix et la diction des paroles.',
      'icon': Icons.mic_none_rounded,
    },
    {
      'name': 'Acoustique',
      'desc': 'Idéal pour le live, la guitare, le piano et les cordes.',
      'icon': Icons.music_note_rounded,
    },
    {
      'name': 'Club & Urbain',
      'desc': 'Énergie maximale avec basses serrées et aigus précis.',
      'icon': Icons.nightlife_rounded,
    },
    {
      'name': 'Nuit Douce',
      'desc': 'Adoucit les fréquences vives pour une écoute reposante.',
      'icon': Icons.bedtime_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _streamingQuality = _storage.streamingQuality;
    _autoplay = _storage.autoplayEnabled;
    _volumeNormalization = _storage.volumeNormalizationEnabled;
    _audioPreset = _storage.audioPreset;
  }

  String _activeQualityLabel() {
    for (final opt in _qualityOptions) {
      if (opt['id'] == _streamingQuality) {
        return '${opt['title']} · ${opt['badge']}';
      }
    }
    return 'Standard · 160 kbps';
  }

  String _activePresetDescription() {
    for (final p in _presets) {
      if (p['name'] == _audioPreset) {
        return p['desc'] as String;
      }
    }
    return 'Profil acoustique personnalisé';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SonoritizDynamicBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
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
                          title: 'Audio & Lecture',
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 1. Résumé actif épuré (style Profil)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROFIL ACTIF',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.42),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _audioPreset,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DÉBIT STREAMING',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.42),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _activeQualityLabel(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Profil acoustique (pastilles nettes, texte noir sur orange)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profil acoustique',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activePresetDescription(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: _presets.map((preset) {
                          final name = preset['name'] as String;
                          final isSelected = _audioPreset == name;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _audioPreset = name);
                              _storage.setAudioPreset(name);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.055),
                                borderRadius: BorderRadius.circular(22),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: Colors.white.withValues(alpha: 0.09),
                                      ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    preset['icon'] as IconData,
                                    size: 16,
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white.withValues(alpha: 0.72),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.white.withValues(alpha: 0.85),
                                      fontSize: 13.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Qualité du streaming (liste ouverte séparée par hairlines)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Qualité du streaming',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Débit audio lors de l’écoute connectée',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_qualityOptions.length, (i) {
                        final opt = _qualityOptions[i];
                        final isSelected = _streamingQuality == opt['id'];
                        final isLast = i == _qualityOptions.length - 1;
                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                final id = opt['id'] as String;
                                setState(() => _streamingQuality = id);
                                _storage.setStreamingQuality(id);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        opt['icon'] as IconData,
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.white.withValues(alpha: 0.7),
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                opt['title'] as String,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                opt['badge'] as String,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : Colors.white
                                                          .withValues(alpha: 0.42),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            opt['description'] as String,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.48),
                                              fontSize: 12.5,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.white
                                                    .withValues(alpha: 0.28),
                                            width: 1.6,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                size: 13,
                                                color: Colors.black,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isLast) _subtleDivider(),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // 4. Confort & lecture (interrupteurs épurés façon Profil)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 180 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Confort & Lecture',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSwitchRow(
                        icon: Icons.equalizer_rounded,
                        title: 'Normalisation du volume',
                        subtitle:
                            'Équilibre le niveau sonore entre les morceaux.',
                        value: _volumeNormalization,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _volumeNormalization = val);
                          _storage.setVolumeNormalizationEnabled(val);
                        },
                      ),
                      _subtleDivider(),
                      _buildSwitchRow(
                        icon: Icons.autorenew_rounded,
                        title: 'Lecture continue (Autoplay)',
                        subtitle:
                            'Enchaîne avec des titres proches en fin de file.',
                        value: _autoplay,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _autoplay = val);
                          _storage.setAutoplayEnabled(val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.75),
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
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
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
