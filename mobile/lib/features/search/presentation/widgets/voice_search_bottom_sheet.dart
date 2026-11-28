import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/artists_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../player/data/models/track_model.dart';
import '../../../home/data/repositories/catalog_repository.dart';
import '../../../home/presentation/cubit/home_cubit.dart';
import '../../../home/presentation/cubit/home_state.dart';
import '../../../player/presentation/cubit/player_cubit.dart';

class VoiceSearchBottomSheet extends StatefulWidget {
  final ValueChanged<String>? onQueryRecognized;

  const VoiceSearchBottomSheet({super.key, this.onQueryRecognized});

  @override
  State<VoiceSearchBottomSheet> createState() => _VoiceSearchBottomSheetState();
}

class _VoiceSearchBottomSheetState extends State<VoiceSearchBottomSheet> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final Dio _lyricsDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 3200),
      receiveTimeout: const Duration(milliseconds: 3500),
    ),
  );

  bool _isListening = false;
  String _text = 'Dites un titre, un artiste ou des paroles...';
  String _cleanedQueryPreview = '';
  bool _isSearching = false;
  List<TrackModel> _foundTracks = [];
  String? _matchedByLyricsLabel;
  String _errorMessage = '';
  double _soundLevel = 0.0;

  /// '' = Auto (langue du système), 'fr_FR' = Français, 'en_US' = Anglais
  String _selectedLocaleId = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speechToText.stop();
    super.dispose();
  }

  void _initSpeech() async {
    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          if (_isListening) {
            setState(() {
              _isListening = false;
              _soundLevel = 0.0;
            });
            _performSearch();
          }
        }
      },
      onError: (errorNotification) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _soundLevel = 0.0;
          _errorMessage = 'Erreur : ${errorNotification.errorMsg}';
        });
      },
    );
    if (!mounted) return;
    if (available) {
      _startListening();
    } else {
      setState(() {
        _errorMessage = 'Reconnaissance vocale indisponible sur cet appareil.';
      });
    }
  }

  void _startListening() {
    setState(() {
      _isListening = true;
      _text = 'Écoute en cours... Parlez maintenant.';
      _cleanedQueryPreview = '';
      _foundTracks = [];
      _matchedByLyricsLabel = null;
      _errorMessage = '';
      _soundLevel = 0.0;
    });

    try {
      _speechToText.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            if (result.recognizedWords.isNotEmpty) {
              _text = result.recognizedWords;
            }
            if (result.finalResult) {
              _isListening = false;
              _soundLevel = 0.0;
              _performSearch();
            }
          });
        },
        onSoundLevelChange: (level) {
          if (!mounted) return;
          final normalized = ((level + 2.0) / 12.0).clamp(0.0, 1.0);
          setState(() => _soundLevel = normalized);
        },
        localeId: _selectedLocaleId.isEmpty ? null : _selectedLocaleId,
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(milliseconds: 2200),
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      setState(() {
        _isListening = false;
        _errorMessage = 'Erreur d’écoute : $e';
      });
    }
  }

  void _stopListening() {
    _speechToText.stop();
    setState(() {
      _isListening = false;
      _soundLevel = 0.0;
    });
    _performSearch();
  }

  /// Nettoie les commandes vocales naturelles (« joue », « mets du », « cherche la chanson »...)
  String _cleanSpokenQuery(String raw) {
    var q = raw.toLowerCase().trim();

    final List<RegExp> commandPrefixes = [
      RegExp(
        r'^(dis\s+sonoritiz|hey\s+sonoritiz|ok\s+sonoritiz)\s+',
        caseSensitive: false,
      ),
      RegExp(
        r'^(je\s+veux\s+écouter|je\s+voudrais\s+écouter|fais\s+écouter|fais-moi\s+écouter|mets-moi|joue-moi|lance-moi)\s+',
        caseSensitive: false,
      ),
      RegExp(
        r'^(joue|jouer|mets|mettre|lance|lancer|écoute|écouter|cherche|chercher|recherche|rechercher|trouve|trouver|play|search\s+for|search|find|listen\s+to|put\s+on)\s+',
        caseSensitive: false,
      ),
      RegExp(
        r'^(la\s+chanson|le\s+morceau|le\s+titre|le\s+son|la\s+musique|un\s+son\s+de|une\s+chanson\s+de|du|de\s+la|the\s+song|the\s+track|music\s+by)\s+',
        caseSensitive: false,
      ),
    ];

    for (final regex in commandPrefixes) {
      q = q.replaceFirst(regex, '').trim();
    }

    q = q
        .replaceAll(RegExp(r'\s+(chanté\s+par|interprété\s+par)\s+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return q.isEmpty ? raw.trim() : q;
  }

  /// Correction phonétique mot par mot / bigramme sans écraser le titre prononcé à côté
  String _applySmartArtistCorrection(
    String cleanedQuery,
    List<String> knownArtists,
  ) {
    final normalizedArtists = knownArtists
        .map((a) => a.trim().toLowerCase())
        .where((a) => a.length >= 3)
        .toSet()
        .toList();
    if (normalizedArtists.isEmpty) return cleanedQuery;

    // 1. Si toute la requête est déjà très proche d'un seul nom d'artiste (et même longueur)
    final fullMatch = cleanedQuery.bestMatch(normalizedArtists);
    final bestFullTarget = fullMatch.bestMatch.target ?? '';
    final bestFullRating = fullMatch.bestMatch.rating ?? 0.0;
    if (bestFullRating >= 0.80 &&
        (cleanedQuery.length - bestFullTarget.length).abs() <= 3) {
      return bestFullTarget;
    }

    // 2. Sinon, correction non-destructive token par token (conserve le titre de la chanson)
    final words = cleanedQuery.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return cleanedQuery;

    final singleWordArtists =
        normalizedArtists.where((a) => !a.contains(' ')).toList();
    final multiWordArtists =
        normalizedArtists.where((a) => a.contains(' ')).toList();

    // Test des bigrammes (ex: "aya nakamura", "the weeknd", "koba lad")
    if (words.length >= 2 && multiWordArtists.isNotEmpty) {
      for (int i = 0; i < words.length - 1; i++) {
        final bigram = '${words[i]} ${words[i + 1]}';
        if (bigram.length < 5) continue;
        final m = bigram.bestMatch(multiWordArtists);
        if ((m.bestMatch.rating ?? 0.0) >= 0.80 && m.bestMatch.target != null) {
          final targetParts = m.bestMatch.target!.split(' ');
          if (targetParts.length == 2) {
            words[i] = targetParts[0];
            words[i + 1] = targetParts[1];
          }
        }
      }
    }

    // Test des mots individuels (ex: "ninho", "tiakola", "damso")
    if (singleWordArtists.isNotEmpty) {
      for (int i = 0; i < words.length; i++) {
        final w = words[i];
        if (w.length < 4) continue;
        final m = w.bestMatch(singleWordArtists);
        if ((m.bestMatch.rating ?? 0.0) >= 0.82 && m.bestMatch.target != null) {
          words[i] = m.bestMatch.target!;
        }
      }
    }

    return words.join(' ');
  }

  /// Interroge LRCLIB pour identifier un morceau à partir de paroles dictées
  Future<List<String>> _searchSongByLyrics(String query) async {
    final wordCount = query.split(' ').where((w) => w.isNotEmpty).length;
    if (wordCount < 2) return const [];

    try {
      final response = await _lyricsDio.get(
        'https://lrclib.net/api/search',
        queryParameters: {'q': query},
      );
      final data = response.data;
      if (data is List && data.isNotEmpty) {
        final List<String> suggestions = [];
        for (final item in data.take(2)) {
          if (item is Map) {
            final trackName = (item['trackName'] ?? '').toString().trim();
            final artistName = (item['artistName'] ?? '').toString().trim();
            if (trackName.isNotEmpty && artistName.isNotEmpty) {
              suggestions.add('$trackName $artistName');
            }
          }
        }
        return suggestions;
      }
    } catch (_) {}
    return const [];
  }

  /// Score de pertinence pour déclasser les versions Karaoké/Instrumental non demandées
  double _scoreCandidateTrack(
    TrackModel track,
    String query, {
    bool isFromLyricsMatch = false,
  }) {
    final qLower = query.toLowerCase();
    final titleLower = track.title.toLowerCase();
    final artistLower = track.artistName.toLowerCase();
    final combined = '$titleLower $artistLower';

    double score = StringSimilarity.compareTwoStrings(qLower, combined) * 100.0;
    final titleSim = StringSimilarity.compareTwoStrings(qLower, titleLower);
    final artistSim = StringSimilarity.compareTwoStrings(qLower, artistLower);
    score += (titleSim * 55.0) + (artistSim * 45.0);

    if (combined.contains(qLower) || titleLower.contains(qLower)) {
      score += 35.0;
    }
    if (isFromLyricsMatch) {
      score += 40.0;
    }

    // Pénaliser les versions parasites si l'utilisateur ne les a pas demandées
    const unwantedMarkers = [
      'karaoke',
      'karaoké',
      'tribute',
      'ringtone',
      '8-bit',
      'made famous by',
      'originally performed by',
    ];
    for (final marker in unwantedMarkers) {
      if (!qLower.contains(marker) &&
          (titleLower.contains(marker) || artistLower.contains(marker))) {
        score -= 80.0;
      }
    }
    if (!qLower.contains('instrumental') &&
        titleLower.contains('instrumental')) {
      score -= 45.0;
    }

    return score;
  }

  Future<void> _performSearch() async {
    if (_text.isEmpty ||
        _text.startsWith('Écoute en cours...') ||
        _text.startsWith('Dites un titre')) {
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = '';
      _matchedByLyricsLabel = null;
    });

    try {
      final List<String> knownArtists = [
        ...ArtistsData.globalArtists
            .map((a) => (a['name'] ?? '').toLowerCase().trim())
            .where((name) => name.isNotEmpty),
        'leto',
        'zola',
        'koba lad',
        'sdm',
        'maes',
        'djadja & dinaz',
        'werenoi',
        'zkr',
        'naps',
        'soolking',
        'rohff',
        'kaaris',
        'vald',
        'lomepal',
        'nekfeu',
        'alpha wann',
        'laylow',
        'dinos',
        'josman',
        'ziak',
        'kerchak',
        'la fève',
        'guy2bezbar',
        'freeze corleone',
        'pnl',
      ];

      CatalogRepository repository;
      try {
        final homeCubit = context.read<HomeCubit?>();
        if (homeCubit != null) {
          final homeState = homeCubit.state;
          if (homeState is HomeLoaded) {
            for (final track in homeState.userFavorites) {
              final favArtist = track.artistName.toLowerCase().trim();
              if (favArtist.isNotEmpty) {
                knownArtists.add(favArtist);
              }
            }
          }
          repository = homeCubit.catalogRepository;
        } else {
          repository = CatalogRepository();
        }
      } catch (_) {
        repository = CatalogRepository();
      }

      // 1. Nettoyage NLP des commandes vocales + correction phonétique non-destructive
      final cleaned = _cleanSpokenQuery(_text);
      final searchQuery = _applySmartArtistCorrection(cleaned, knownArtists);

      if (mounted) {
        setState(() => _cleanedQueryPreview = searchQuery);
      }

      widget.onQueryRecognized?.call(searchQuery);

      // 2. Recherche hybride en parallèle : Catalogue direct + Recherche par Paroles (LRCLIB)
      final resultsFutures = await Future.wait([
        repository.searchTracks(query: searchQuery, limit: 8),
        _searchSongByLyrics(cleaned),
      ]);

      final directResults = resultsFutures[0] as List<TrackModel>;
      final lyricsMatches = resultsFutures[1] as List<String>;

      final List<TrackModel> lyricsTracks = [];
      if (lyricsMatches.isNotEmpty) {
        final fetchedFromLyrics = await repository.searchTracks(
          query: lyricsMatches.first,
          limit: 3,
        );
        lyricsTracks.addAll(fetchedFromLyrics);
      }

      // 3. Fusion sans doublon & classement de pertinence anti-karaoké
      final Map<String, TrackModel> uniqueById = {};
      final Map<String, double> scoresById = {};

      for (final t in directResults) {
        if (t.id.isEmpty) continue;
        uniqueById[t.id] = t;
        scoresById[t.id] = _scoreCandidateTrack(t, searchQuery);
      }

      for (final t in lyricsTracks) {
        if (t.id.isEmpty) continue;
        uniqueById[t.id] = t;
        final s = _scoreCandidateTrack(
          t,
          lyricsMatches.first,
          isFromLyricsMatch: true,
        );
        final prev = scoresById[t.id] ?? -999.0;
        if (s > prev) scoresById[t.id] = s;
      }

      final rankedTracks = uniqueById.values.toList()
        ..sort(
          (a, b) => (scoresById[b.id] ?? 0.0).compareTo(scoresById[a.id] ?? 0.0),
        );

      if (!mounted) return;

      if (rankedTracks.isNotEmpty) {
        setState(() {
          _foundTracks = rankedTracks.take(3).toList();
          if (lyricsTracks.isNotEmpty &&
              lyricsTracks.any((lt) => lt.id == _foundTracks.first.id)) {
            _matchedByLyricsLabel = 'Identifié via les paroles';
          }
          _isSearching = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Aucun résultat trouvé pour « $searchQuery »';
          _isSearching = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erreur lors de la recherche vocale.';
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageSelectorRow(),
            const SizedBox(height: 18),
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    if (_cleanedQueryPreview.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Recherche de « $_cleanedQueryPreview »...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else if (_foundTracks.isNotEmpty)
              _buildResultWidget()
            else
              _buildListeningWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelectorRow() {
    final options = const [
      {'id': '', 'label': 'Auto'},
      {'id': 'fr_FR', 'label': '🇫🇷 FR'},
      {'id': 'en_US', 'label': '🇬🇧 EN'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              color: AppColors.primary,
              size: 18,
            ),
            SizedBox(width: 7),
            Text(
              'Recherche Vocale',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final id = opt['id']!;
              final isSelected = _selectedLocaleId == id;
              return GestureDetector(
                onTap: () {
                  if (_selectedLocaleId == id) return;
                  setState(() => _selectedLocaleId = id);
                  if (_isListening) {
                    _speechToText.stop();
                    Future.delayed(
                      const Duration(milliseconds: 180),
                      () {
                        if (mounted) _startListening();
                      },
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    opt['label']!,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildListeningWidget() {
    final dynamicSpread = 4.0 + (_soundLevel * 18.0);
    final dynamicBlur = 16.0 + (_soundLevel * 22.0);

    return Column(
      children: [
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _isListening ? _stopListening : _startListening,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? AppColors.primary : Colors.white10,
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.52),
                        blurRadius: dynamicBlur,
                        spreadRadius: dynamicSpread,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: _isListening ? Colors.black : Colors.white,
              size: 40,
            ),
          )
              .animate(target: _isListening ? 1 : 0)
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.08, 1.08),
                duration: 480.ms,
                curve: Curves.easeInOut,
              )
              .then(delay: 480.ms)
              .scale(
                begin: const Offset(1.08, 1.08),
                end: const Offset(1, 1),
                duration: 480.ms,
                curve: Curves.easeInOut,
              ),
        ),
        const SizedBox(height: 22),
        Text(
          _text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ex : « Joue Lettre à une femme de Ninho » ou dictez un refrain',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _startListening,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            label: const Text(
              'Réessayer',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultWidget() {
    final topTrack = _foundTracks.first;
    final alternatives = _foundTracks.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _matchedByLyricsLabel ?? 'Meilleur résultat trouvé',
              style: TextStyle(
                color: _matchedByLyricsLabel != null
                    ? AppColors.primary
                    : Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.45),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: topTrack.coverUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              topTrack.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              topTrack.artistName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: 24,
              ),
            ),
            onTap: () {
              context.read<PlayerCubit>().playTrack(
                    topTrack,
                    queue: _foundTracks,
                    source: 'Recherche vocale',
                  );
              context.pop();
            },
          ),
        ),
        if (alternatives.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Autres correspondances proches',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...alternatives.map(
            (track) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: track.coverUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    track.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    track.artistName,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    Icons.play_circle_outline_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  onTap: () {
                    context.read<PlayerCubit>().playTrack(
                          track,
                          queue: _foundTracks,
                          source: 'Recherche vocale',
                        );
                    context.pop();
                  },
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _foundTracks = [];
                  _text = 'Dites un titre, un artiste ou des paroles...';
                });
                _startListening();
              },
              icon: const Icon(Icons.mic_rounded, size: 17),
              label: const Text('Rechercher à nouveau'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
