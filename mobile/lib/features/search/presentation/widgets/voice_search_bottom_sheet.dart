import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:string_similarity/string_similarity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../player/data/models/track_model.dart';
import '../../../home/presentation/cubit/home_cubit.dart';
import '../../../home/presentation/cubit/home_state.dart';
import '../../../player/presentation/cubit/player_cubit.dart';

class VoiceSearchBottomSheet extends StatefulWidget {
  const VoiceSearchBottomSheet({super.key});

  @override
  State<VoiceSearchBottomSheet> createState() => _VoiceSearchBottomSheetState();
}

class _VoiceSearchBottomSheetState extends State<VoiceSearchBottomSheet> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  String _text = 'Dites le titre ou des paroles...';
  bool _isSearching = false;
  TrackModel? _foundTrack;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    bool available = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_isListening) {
            setState(() => _isListening = false);
            _performSearch();
          }
        }
      },
      onError: (errorNotification) {
        setState(() {
          _isListening = false;
          _errorMessage = 'Erreur : ${errorNotification.errorMsg}';
        });
      },
    );
    if (available) {
      _startListening();
    } else {
      setState(() {
        _errorMessage = "Reconnaissance vocale indisponible.";
      });
    }
  }

  void _startListening() {
    setState(() {
      _isListening = true;
      _text = 'Écoute en cours... Parlez maintenant.';
      _foundTrack = null;
      _errorMessage = '';
    });
    
    try {
      _speechToText.listen(
        onResult: (result) {
          setState(() {
            if (result.recognizedWords.isNotEmpty) {
              _text = result.recognizedWords;
            }
            if (result.finalResult) {
              _isListening = false;
              _performSearch();
            }
          });
        },
        cancelOnError: true,
        // Removed localeId to use system default
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      setState(() {
        _isListening = false;
        _errorMessage = 'Erreur d\'écoute: $e';
      });
    }
  }

  void _stopListening() {
    _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _performSearch() async {
    if (_text.isEmpty || _text.startsWith('Écoute en cours...') || _text == 'Dites le titre ou des paroles...') {
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = '';
    });

    try {
      String searchQuery = _text.toLowerCase().trim();
      
      // Liste étendue d'artistes populaires (francophones + internationaux)
      final List<String> globalArtists = [
        'ninho', 'leto', 'gazo', 'plk', 'tiakola', 'jul', 'damso', 'booba', 'orelsan', 'niska',
        'zola', 'koba lad', 'sdm', 'maes', 'sch', 'hamza', 'djadja & dinaz', 'werenoi', 'zkr',
        'heuss l\'enfoiré', 'naps', 'soolking', 'aya nakamura', 'tayc', 'dadju', 'franglish',
        'gims', 'soprano', 'rohff', 'kaaris', 'vald', 'lomepal', 'nekfeu', 'alpha wann',
        'laylow', 'dinos', 'josman', 'ziak', 'kerchak', 'la fève', 'guy2bezbar', 'freeze corleone',
        'pnl', 'dj snake', 'stromae', 'angele', 'the weeknd', 'drake', 'travis scott', 'rihanna',
        'beyonce', 'eminem', 'kanye west', 'taylor swift', 'dua lipa', 'ed sheeran', 'justin bieber'
      ];

      // On ajoute aussi les artistes favoris de l'utilisateur
      final homeState = context.read<HomeCubit>().state;
      if (homeState is HomeLoaded) {
        for (var track in homeState.userFavorites) {
          final favArtist = track.artistName.toLowerCase().trim();
          if (!globalArtists.contains(favArtist)) {
            globalArtists.add(favArtist);
          }
        }
      }

      // Utilisation de l'algorithme Dice Coefficient pour trouver la meilleure correspondance
      final match = searchQuery.bestMatch(globalArtists);
      if (match.bestMatch.rating! > 0.65) {
        // Si la ressemblance est > 65%, on corrige la requête
        searchQuery = match.bestMatch.target!;
      }

      final repository = context.read<HomeCubit>().catalogRepository;
      final results = await repository.searchTracks(query: searchQuery, limit: 1);

      if (results.isNotEmpty) {
        setState(() {
          _foundTrack = results.first;
          _isSearching = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Aucun résultat trouvé pour "$searchQuery"';
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la recherche.';
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSearching)
              const CircularProgressIndicator(color: AppColors.primary)
            else if (_foundTrack != null)
              _buildResultWidget()
            else
              _buildListeningWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningWidget() {
    return Column(
      children: [
        GestureDetector(
          onTap: _isListening ? _stopListening : _startListening,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? AppColors.primary : Colors.white10,
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ]
                  : [],
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 40,
            ),
          ).animate(target: _isListening ? 1 : 0).scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: 500.ms,
                curve: Curves.easeInOut,
              ).then(delay: 500.ms).scale(
                begin: const Offset(1.1, 1.1),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.easeInOut,
              ),
        ),
        const SizedBox(height: 24),
        Text(
          _text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultWidget() {
    return Column(
      children: [
        const Text(
          "Résultat trouvé",
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: _foundTrack!.coverUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          title: Text(
            _foundTrack!.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _foundTrack!.artistName,
            style: const TextStyle(color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.play_arrow, color: AppColors.primary),
          onTap: () {
            context.read<PlayerCubit>().playTrack(_foundTrack!);
            context.pop();
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _foundTrack = null;
              _text = 'Dites le titre ou des paroles...';
            });
            _startListening();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text("Rechercher à nouveau"),
        ),
      ],
    );
  }
}
