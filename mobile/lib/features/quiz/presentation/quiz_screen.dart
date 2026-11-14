import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../core/widgets/sonoritiz_page_title.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../home/data/repositories/catalog_repository.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({Key? key}) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final CatalogRepository _catalogRepository;

  List<TrackModel> _quizTracks = [];
  List<TrackModel> _poolTracks = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _isAnswered = false;
  String? _selectedOption;

  late String _correctAnswer;
  List<String> _options = [];
  late bool _askForArtist;

  Timer? _countdownTimer;
  int _timeLeft = 20;

  @override
  void initState() {
    super.initState();
    _catalogRepository = CatalogRepository(
      apiClient: ApiClient(storageService: StorageService()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pause la musique globale pour lancer le Blind Test
      try {
        context.read<PlayerCubit>().pause();
      } catch (_) {}
      _loadQuizData();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadQuizData() async {
    setState(() {
      _isLoading = true;
      _currentQuestionIndex = 0;
      _score = 0;
    });

    try {
      final tracks = await _catalogRepository.getQuizTracks(limit: 35);
      final validTracks = tracks
          .where((t) => t.audioUrl.isNotEmpty && t.title.isNotEmpty && t.artistName.isNotEmpty)
          .toList();

      if (validTracks.length >= 10) {
        validTracks.shuffle();
        _poolTracks = List<TrackModel>.from(validTracks);
        _quizTracks = validTracks.take(10).toList();
      } else {
        _useFallbackTracks();
      }
    } catch (_) {
      _useFallbackTracks();
    }

    if (mounted) {
      _prepareQuestion();
    }
  }

  void _useFallbackTracks() {
    final fallbacks = [
      const TrackModel(
        id: 'deezer_3135556',
        title: 'Harder, Better, Faster, Stronger',
        artistName: 'Daft Punk',
        albumName: 'Discovery',
        coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/2e018122cb56986277102d2041a592c8/500x500.jpg',
        durationSeconds: 30,
        audioUrl: 'https://cdns-preview-d.dzcdn.net/stream/c-d2c6974d0e408ec20092f6b801a61dc4-4.mp3',
      ),
      const TrackModel(
        id: 'deezer_1109731',
        title: 'Billie Jean',
        artistName: 'Michael Jackson',
        albumName: 'Thriller',
        coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/67f1ee0f55cf736c0bf812fa4bcf0e04/500x500.jpg',
        durationSeconds: 30,
        audioUrl: 'https://cdns-preview-6.dzcdn.net/stream/c-6fe22e5a31a5cb1d92ee950b71946892-7.mp3',
      ),
      const TrackModel(
        id: 'deezer_68981084',
        title: 'Papaoutai',
        artistName: 'Stromae',
        albumName: 'Racine Carrée',
        coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/6c23bf987258a18fa6676cf744fc6efb/500x500.jpg',
        durationSeconds: 30,
        audioUrl: 'https://cdns-preview-9.dzcdn.net/stream/c-9cf113cfca848d706692bb7165da6423-8.mp3',
      ),
      const TrackModel(
        id: 'deezer_868310322',
        title: 'Blinding Lights',
        artistName: 'The Weeknd',
        albumName: 'After Hours',
        coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/686f0ea9f20612c759550346a06148ee/500x500.jpg',
        durationSeconds: 30,
        audioUrl: 'https://cdns-preview-b.dzcdn.net/stream/c-b715206ecae0d8adcf9a0f0f37e448ee-6.mp3',
      ),
      const TrackModel(
        id: 'deezer_1749842237',
        title: 'Calm Down',
        artistName: 'Rema',
        albumName: 'Rave & Roses',
        coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/0ba6ea724771e7a5dc4be9426f86348c/500x500.jpg',
        durationSeconds: 30,
        audioUrl: 'https://cdns-preview-d.dzcdn.net/stream/c-d3fe896b05bfdc360a7ad9e58564e9a0-6.mp3',
      ),
      const TrackModel(
        id: 'deezer_70603750',
        title: 'Tous les mêmes',
        artistName: 'Stromae',
        albumName: 'Racine Carrée',
        coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/6c23bf987258a18fa6676cf744fc6efb/500x500.jpg',
        durationSeconds: 30,
        audioUrl: 'https://cdns-preview-0.dzcdn.net/stream/c-0f9435b62e49c718a368d904791e8432-6.mp3',
      ),
      const TrackModel(
        id: 'deezer_14363907',
        title: 'Rolling in the Deep',
        artistName: 'Adele',
        albumName: '21',
        coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/b4bb98d4fb97171a81d4e0e5a9591418/500x500.jpg',
        durationSeconds: 30,
        audioUrl: 'https://cdns-preview-3.dzcdn.net/stream/c-3a9ec11488e0dcbf315ec0177fc20c4e-5.mp3',
      ),
      const TrackModel(
        id: 'deezer_136338472',
        title: 'Shape of You',
        artistName: 'Ed Sheeran',
        albumName: 'Divide',
        coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/9ec9036f04c64d852a4cf5f9575e9b89/500x500.jpg',
        durationSeconds: 30,
        audioUrl: 'https://cdns-preview-d.dzcdn.net/stream/c-d652f14aa0c9d7491cf0eb2625345719-7.mp3',
      ),
      const TrackModel(
        id: 'deezer_1749842238',
        title: 'Last Last',
        artistName: 'Burna Boy',
        albumName: 'Love, Damini',
        coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/15479ae4dc6946be4975945ff6f90119/500x500.jpg',
        durationSeconds: 30,
        audioUrl: 'https://cdns-preview-4.dzcdn.net/stream/c-4740e536f9a0cb98ae4b4b2c159842ec-4.mp3',
      ),
      const TrackModel(
        id: 'deezer_519125322',
        title: 'Djadja',
        artistName: 'Aya Nakamura',
        albumName: 'NAKAMURA',
        coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/2c56a84d4fb451308a38ae9808381289/500x500.jpg',
        durationSeconds: 30,
        audioUrl: 'https://cdns-preview-5.dzcdn.net/stream/c-5f80b27bb8f19293141f92e92ec79c4a-6.mp3',
      ),
      const TrackModel(
        id: 'deezer_142986206',
        title: 'Despacito',
        artistName: 'Luis Fonsi',
        albumName: 'VIDA',
        coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/b4f535941c9f28c2ffaa6333bf9cf7d9/500x500.jpg',
        durationSeconds: 30,
        audioUrl: 'https://cdns-preview-4.dzcdn.net/stream/c-4860fb785a03425cb9c02b1fffe5518b-6.mp3',
      ),
    ];
    fallbacks.shuffle();
    _poolTracks = List<TrackModel>.from(fallbacks);
    _quizTracks = fallbacks.take(10).toList();
  }

  Future<void> _prepareQuestion() async {
    if (_currentQuestionIndex >= 10 || _currentQuestionIndex >= _quizTracks.length) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _isAnswered = false;
      _selectedOption = null;
      _timeLeft = 20;
    });

    final currentTrack = _quizTracks[_currentQuestionIndex];

    // Aléatoire : demande le titre ou l'artiste
    _askForArtist = Random().nextBool();
    _correctAnswer = _askForArtist ? currentTrack.artistName : currentTrack.title;

    // Générer 3 mauvaises options distinctes
    final Set<String> wrongOptions = {};
    final shuffledPool = List<TrackModel>.from(_poolTracks)..shuffle();

    for (final t in shuffledPool) {
      if (t.id == currentTrack.id) continue;
      final wrong = _askForArtist ? t.artistName : t.title;
      if (wrong.trim().isNotEmpty && wrong.toLowerCase() != _correctAnswer.toLowerCase()) {
        wrongOptions.add(wrong);
      }
      if (wrongOptions.length >= 3) break;
    }

    // Compléter avec des fallbacks connus si nécessaire
    final defaultArtists = ['Burna Boy', 'Stromae', 'Aya Nakamura', 'The Weeknd', 'Daft Punk', 'Adele', 'Ed Sheeran', 'Rema'];
    final defaultTitles = ['Calm Down', 'Blinding Lights', 'Papaoutai', 'Djadja', 'Billie Jean', 'Shape of You', 'Rolling in the Deep'];
    final fallbackList = _askForArtist ? defaultArtists : defaultTitles;
    for (final f in fallbackList) {
      if (wrongOptions.length >= 3) break;
      if (f.toLowerCase() != _correctAnswer.toLowerCase()) {
        wrongOptions.add(f);
      }
    }

    _options = wrongOptions.toList();
    _options.add(_correctAnswer);
    _options.shuffle();

    // Lancer la lecture audio de l'extrait
    try {
      await _audioPlayer.stop();
      if (currentTrack.audioUrl.isNotEmpty) {
        await _audioPlayer.setUrl(currentTrack.audioUrl).timeout(const Duration(seconds: 4));
        unawaited(_audioPlayer.play());
      }
    } catch (e) {
      print('Erreur lecture audio quiz: $e');
      // Remplacer le son défectueux par un autre du pool SANS avancer la question
      final alternatives = _poolTracks.where((t) => t.id != currentTrack.id && t.audioUrl.isNotEmpty).toList();
      if (alternatives.isNotEmpty) {
        alternatives.shuffle();
        _quizTracks[_currentQuestionIndex] = alternatives.first;
        if (mounted) {
          _prepareQuestion();
          return;
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _startTimer();
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _handleAnswer(null);
        }
      });
    });
  }

  void _handleAnswer(String? selected) {
    if (_isAnswered) return;
    _countdownTimer?.cancel();

    setState(() {
      _isAnswered = true;
      _selectedOption = selected;
      if (selected == _correctAnswer) {
        _score += 10;
      }
    });

    _audioPlayer.stop();

    // Attente de 2.2s pour montrer la réponse et la pochette révélée
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _currentQuestionIndex++;
        });
        if (_currentQuestionIndex < 10) {
          _prepareQuestion();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const SonoritizPageTitle(
          title: "Quiz Musical Sonoritiz",
          fontSize: 20,
          centered: true,
        ),
        centerTitle: true,
      ),
      body: _currentQuestionIndex >= 10
          ? _buildResultScreen()
          : _buildQuizScreen(),
    );
  }

  Widget _buildQuizScreen() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            const SizedBox(height: 24),
            const Text(
              "Préparation du morceau...",
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
            ).animate().shimmer(duration: 1.seconds, curve: Curves.easeInOut),
          ],
        ),
      );
    }

    final currentTrack = _quizTracks.length > _currentQuestionIndex
        ? _quizTracks[_currentQuestionIndex]
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header : Question N/10 et Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Question ${_currentQuestionIndex + 1}/10",
                style: const TextStyle(color: Colors.white60, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFA7921), Color(0xFFFF9100)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFA7921).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  "Score: $_score pts",
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // Cercle central animé (Note musicale ou Pochette révélée après réponse)
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isAnswered
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFA7921), Color(0xFFFF9100)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (_isAnswered && _selectedOption == _correctAnswer)
                        ? Colors.green.withOpacity(0.4)
                        : const Color(0xFFFA7921).withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: (_isAnswered && currentTrack != null && currentTrack.coverUrl.isNotEmpty)
                    ? SonoritizArtwork(
                        imageUrl: currentTrack.coverUrl,
                        width: 170,
                        height: 170,
                        shape: BoxShape.circle,
                      )
                    : const Icon(Icons.music_note_rounded, size: 75, color: Colors.white),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.04, 1.04), duration: 900.ms, curve: Curves.easeInOut),
          ),

          const SizedBox(height: 18),

          // Timer circulaire / décompte
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: _timeLeft <= 5 ? Colors.redAccent : const Color(0xFFFA7921),
                ),
                const SizedBox(width: 6),
                Text(
                  "00:${_timeLeft.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    color: _timeLeft <= 5 ? Colors.redAccent : Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Question posée ou Révélation du son
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isAnswered && currentTrack != null
                ? Column(
                    key: const ValueKey('revealed'),
                    children: [
                      Text(
                        currentTrack.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentTrack.artistName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFA7921),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _askForArtist ? "Quel est le nom de cet artiste ?" : "Quel est le titre de ce morceau ?",
                    key: const ValueKey('question'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18.5, fontWeight: FontWeight.bold),
                  ),
          ),

          const SizedBox(height: 24),

          // Les 4 options de réponse
          Expanded(
            child: ListView.separated(
              itemCount: _options.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final option = _options[index];
                final isSelected = _selectedOption == option;
                final isCorrect = option == _correctAnswer;

                Color buttonColor = Colors.white.withOpacity(0.07);
                Color textColor = Colors.white;
                Color borderColor = Colors.white.withOpacity(0.12);
                Widget? feedbackIcon;

                if (_isAnswered) {
                  if (isCorrect) {
                    buttonColor = Colors.green.withOpacity(0.25);
                    textColor = Colors.greenAccent.shade100;
                    borderColor = Colors.greenAccent;
                    feedbackIcon = const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20);
                  } else if (isSelected && !isCorrect) {
                    buttonColor = Colors.red.withOpacity(0.25);
                    textColor = Colors.redAccent.shade100;
                    borderColor = Colors.redAccent;
                    feedbackIcon = const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 20);
                  }
                } else if (isSelected) {
                  buttonColor = const Color(0xFFFA7921).withOpacity(0.2);
                  borderColor = const Color(0xFFFA7921);
                }

                return GestureDetector(
                  onTap: () => _handleAnswer(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                    decoration: BoxDecoration(
                      color: buttonColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index), // A, B, C, D
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (feedbackIcon != null) feedbackIcon,
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

  Widget _buildResultScreen() {
    String rankBadge = "🥉 Pas mal !";
    String subtitle = "Continue à écouter pour améliorer tes réflexes musicaux !";
    Color badgeColor = const Color(0xFFFF9F43);

    if (_score >= 80) {
      rankBadge = "🏆 Maître Musical !";
      subtitle = "Une oreille absolue ! Tu es incollable sur les hits !";
      badgeColor = const Color(0xFFFFDF00);
    } else if (_score >= 50) {
      rankBadge = "🥈 Bon Mélomane !";
      subtitle = "Très beau score ! Tu connais vraiment tes classiques !";
      badgeColor = const Color(0xFFE2E8F0);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeColor.withOpacity(0.12),
                border: Border.all(color: badgeColor.withOpacity(0.4), width: 2),
              ),
              child: Icon(Icons.emoji_events_rounded, size: 70, color: badgeColor),
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 20),

            Text(
              rankBadge,
              style: TextStyle(color: badgeColor, fontSize: 26, fontWeight: FontWeight.w900),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 8),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14.5),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                "$_score / 100",
                style: const TextStyle(color: Color(0xFFFA7921), fontSize: 34, fontWeight: FontWeight.w900),
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loadQuizData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  elevation: 6,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.replay_rounded, color: Colors.black),
                    SizedBox(width: 8),
                    Text("REJOUER", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: 14),

            TextButton(
              onPressed: () => context.pop(),
              child: const Text("Retour à l'accueil", style: TextStyle(color: Colors.white60, fontSize: 15)),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
