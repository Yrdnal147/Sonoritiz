import 'dart:math' as math;
import '../../../core/constants/artists_data.dart';
import '../../player/data/models/track_model.dart';

/// Grandes familles musicales utilisées pour le profilage contenu + affinités.
enum TasteFamily {
  classical,
  chanson,
  jazzSoul,
  popRock,
  rnb,
  hipHop,
  afro,
  electro,
  latinWorld,
}

/// Définition d'une émotion pour Sonoritiz Moods.
class MoodEmotionSpec {
  final String id;
  final String label;
  final int bubbleColorHex;
  final double valence; // 0 (sombre) -> 1 (lumineux)
  final double energy; // 0 (calme) -> 1 (intense)
  final List<String> deezerMoodQueries;
  final Map<TasteFamily, List<String>> familyQueries;

  const MoodEmotionSpec({
    required this.id,
    required this.label,
    required this.bubbleColorHex,
    required this.valence,
    required this.energy,
    required this.deezerMoodQueries,
    required this.familyQueries,
  });
}

class UserTasteProfile {
  final Map<String, double> artistWeights;
  final Map<TasteFamily, double> familyScores;
  final Set<String> preferredTrackIds;
  final Set<String> dislikedOrFilteredIds;

  const UserTasteProfile({
    required this.artistWeights,
    required this.familyScores,
    this.preferredTrackIds = const {},
    this.dislikedOrFilteredIds = const {},
  });

  factory UserTasteProfile.empty() => const UserTasteProfile(
        artistWeights: {},
        familyScores: {},
      );

  bool get isColdStart => artistWeights.isEmpty;

  List<String> get topAnchorArtists {
    final entries = artistWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  List<TasteFamily> get dominantFamilies {
    final entries = familyScores.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  bool hasFamilyAffinity(TasteFamily family, {double threshold = 0.08}) {
    if (isColdStart) return false;
    return (familyScores[family] ?? 0.0) >= threshold;
  }

  bool get hasAfroAffinity => hasFamilyAffinity(TasteFamily.afro, threshold: 0.07);

  bool get hasHipHopAffinity => hasFamilyAffinity(TasteFamily.hipHop, threshold: 0.07);

  bool get hasUsPopHipHopAffinity =>
      isColdStart ||
      hasFamilyAffinity(TasteFamily.popRock) ||
      hasFamilyAffinity(TasteFamily.hipHop) ||
      hasFamilyAffinity(TasteFamily.rnb) ||
      hasFamilyAffinity(TasteFamily.jazzSoul) ||
      hasFamilyAffinity(TasteFamily.electro);
}

/// Moteur hybride de recommandation basé sur le contenu et le graphe d'artistes.
///
/// Strictement isolé sur les signaux du compte actif :
/// 1. Artistes choisis à l'onboarding ou suivis dans Sonoritiz (+3.5)
/// 2. Superlikes (+3.0) & Likes/Albums favoris (+2.2)
/// 3. Historique d'écoute récent pondéré par récence exponentielle & répétition
/// 4. Recherches d'artistes propres au compte (+0.9)
class RecommendationEngine {
  static const List<MoodEmotionSpec> moodEmotions = [
    MoodEmotionSpec(
      id: 'joie',
      label: 'Joie',
      bubbleColorHex: 0xFFFFC83D,
      valence: 0.95,
      energy: 0.80,
      deezerMoodQueries: ['happy feel good hits', 'upbeat uplifting songs', 'joie musique positive'],
      familyQueries: {
        TasteFamily.classical: ['vivaldi spring alegre', 'mozart eine kleine nachtmusik', 'handel joyful classical'],
        TasteFamily.chanson: ['joe dassin les champs elysees', 'clara luciani la grenade', 'zaz je veux'],
        TasteFamily.jazzSoul: ['stevie wonder signed sealed', 'earth wind fire september', 'louis armstrong wonderful world'],
        TasteFamily.popRock: ['pharrell williams happy', 'katy perry firework', 'coldplay adventure of a lifetime'],
        TasteFamily.rnb: ['bruno mars treasure', 'alicia keys girl on fire', 'beyonce love on top'],
        TasteFamily.hipHop: ['outkast hey ya', 'kendrick lamar i', 'bigflo oli dommage'],
        TasteFamily.afro: ['burna boy on the low', 'rema calm down', 'magic system premier gaou'],
        TasteFamily.electro: ['daft punk get lucky', 'avicii wake me up', 'calvin harris feel so close'],
        TasteFamily.latinWorld: ['shakira waka waka', 'luis fonsi despacito', 'bad bunny titi me pregunto'],
      },
    ),
    MoodEmotionSpec(
      id: 'tristesse',
      label: 'Tristesse',
      bubbleColorHex: 0xFF4F7CAC,
      valence: 0.12,
      energy: 0.25,
      deezerMoodQueries: ['sad emotional ballad', 'heartbreak acoustic', 'chanson triste piano'],
      familyQueries: {
        TasteFamily.classical: ['chopin nocturne tristesse', 'albinoni adagio', 'samuel barber adagio for strings'],
        TasteFamily.chanson: ['jacques brel ne me quitte pas', 'edith piaf hymne a l amour', 'barbara dis quand reviendras tu'],
        TasteFamily.jazzSoul: ['nina simone ne me quitte pas', 'billie holiday gloomy sunday', 'sam cooke change gonna come'],
        TasteFamily.popRock: ['adele someone like you', 'coldplay fix you', 'billie eilish when the party is over'],
        TasteFamily.rnb: ['frank ocean ivy', 'sza snooze', 'toni braxton unbreak my heart'],
        TasteFamily.hipHop: ['eminem mockingbird', 'juice wrld lucid dreams', 'nepal rien d special'],
        TasteFamily.afro: ['omah lay soso', 'tems free mind', 'locko je serai la'],
        TasteFamily.electro: ['robert miles children', 'moby why does my heart feel so bad', 'fred again adore u'],
        TasteFamily.latinWorld: ['natalia lafourcade hasta la raiz', 'camila te confieso', 'marcianeke triste'],
      },
    ),
    MoodEmotionSpec(
      id: 'nostalgie',
      label: 'Nostalgie',
      bubbleColorHex: 0xFFA67DB8,
      valence: 0.42,
      energy: 0.35,
      deezerMoodQueries: ['nostalgic classics', 'retro golden memories', 'chansons souvenirs'],
      familyQueries: {
        TasteFamily.classical: ['yann tiersen comptine d un autre ete', 'debussy clair de lune', 'erik satie gymnopedie'],
        TasteFamily.chanson: ['charles aznavour hier encore', 'jean jacques goldman la bas', 'dalida mourir sur scene'],
        TasteFamily.jazzSoul: ['frank sinatra my way', 'nat king cole unforgettable', 'ella fitzgerald autumn leaves'],
        TasteFamily.popRock: ['queen bohemian rhapsody', 'elton john tiny dancer', 'the beatles yesterday'],
        TasteFamily.rnb: ['marvin gaye lets get it on', 'whitney houston i will always love you', 'usher confessions'],
        TasteFamily.hipHop: ['tupac changes', 'nas the world is yours', 'iam petit frere'],
        TasteFamily.afro: ['manu dibango soul makossa', 'youssou ndour 7 seconds', 'p square no one like you'],
        TasteFamily.electro: ['daft punk instant crush', 'modjo lady hear me tonight', 'kavinsky nightcall'],
        TasteFamily.latinWorld: ['buena vista social club chan chan', 'santana maria maria', 'julio iglesias nostalgie'],
      },
    ),
    MoodEmotionSpec(
      id: 'amour',
      label: 'L’amour',
      bubbleColorHex: 0xFFE95C78,
      valence: 0.78,
      energy: 0.50,
      deezerMoodQueries: ['romantic love songs', 'chansons d amour', 'slow rnb romance'],
      familyQueries: {
        TasteFamily.classical: ['liszt liebestraum love dream', 'tchaikovsky romeo juliet', 'elgar salut d amour'],
        TasteFamily.chanson: ['edith piaf la vie en rose', 'francis cabrel je l aime a mourir', 'celine dion pour que tu m aimes encore'],
        TasteFamily.jazzSoul: ['etta james at last', 'john legend all of me', 'marvin gaye aint no mountain'],
        TasteFamily.popRock: ['ed sheeran perfect', 'bruno mars just the way you are', 'elvis presley cant help falling in love'],
        TasteFamily.rnb: ['alicia keys if i aint got you', 'tayc le temps', 'daniel caesar best part'],
        TasteFamily.hipHop: ['method man mary j blige you are all i need', 'kanye west bound 2', 'dadju reine'],
        TasteFamily.afro: ['ckay love nwantiti', 'joeboy baby', 'charlotte dipanda elle n a pas vu'],
        TasteFamily.electro: ['kygo firestone', 'calvin harris how deep is your love', 'kungs never going home'],
        TasteFamily.latinWorld: ['enrique iglesias hero', 'marc anthony vivire', 'camila cabello havana'],
      },
    ),
    MoodEmotionSpec(
      id: 'serenite',
      label: 'Sérénité',
      bubbleColorHex: 0xFF4ECDC4,
      valence: 0.65,
      energy: 0.15,
      deezerMoodQueries: ['peaceful acoustic ambient', 'calm meditation piano', 'serenite detente'],
      familyQueries: {
        TasteFamily.classical: ['ludovico einaudi nuvole bianche', 'max richter on the nature of daylight', 'bach air on g string'],
        TasteFamily.chanson: ['alain souchon foule sentimentale', 'carla bruni quelq un m a dit', 'zaho de sagazan'],
        TasteFamily.jazzSoul: ['norah jones come away with me', 'miles davis blue in green', 'chetbaker almost blue'],
        TasteFamily.popRock: ['coldplay sparks', 'simon garfunkel sound of silence', 'jack johnson better together'],
        TasteFamily.rnb: ['sade smooth operator', 'corinne bailey rae put your records on', 'h e r focus'],
        TasteFamily.hipHop: ['nujabes feather', 'loyle carner', 'jdilla donuts'],
        TasteFamily.afro: ['tems essence', 'richard bona', 'asa jailer acoustic'],
        TasteFamily.electro: ['petit biscuit sunset lover', 'tycho awake', 'bonobo cirrus'],
        TasteFamily.latinWorld: ['antonio carlos jobim garota de ipanema', 'joao gilberto', 'seu jorge'],
      },
    ),
    MoodEmotionSpec(
      id: 'excitation',
      label: 'Excitation',
      bubbleColorHex: 0xFFFF4D6D,
      valence: 0.85,
      energy: 0.96,
      deezerMoodQueries: ['high energy workout', 'party anthem hype', 'adrenaline hits'],
      familyQueries: {
        TasteFamily.classical: ['vivaldi summer presto', 'beethoven 9th symphony', 'carmina burana o fortuna'],
        TasteFamily.chanson: ['stromae alors on danse', 'indochine l aventurier', 'maitre gims bella'],
        TasteFamily.jazzSoul: ['james brown i got you feel good', 'stevie wonder superstition', 'ray charles hit the road jack'],
        TasteFamily.popRock: ['queen dont stop me now', 'the weeknd blinding lights', 'dua lipa levitating'],
        TasteFamily.rnb: ['beyonce crazy in love', 'usher yeah', 'chris brown forever'],
        TasteFamily.hipHop: ['eminem lose yourself', 'travis scott sicko mode', 'ninho jefe'],
        TasteFamily.afro: ['asake lonely at the top', 'burna boy last last', 'davido unavailable'],
        TasteFamily.electro: ['david guetta titanium', 'martin garrix animals', 'skrillex bangarang'],
        TasteFamily.latinWorld: ['daddy yankee gasolina', 'j balvin mi gente', 'rosalia despecha'],
      },
    ),
    MoodEmotionSpec(
      id: 'melancolie',
      label: 'Mélancolie',
      bubbleColorHex: 0xFF6B5B95,
      valence: 0.25,
      energy: 0.30,
      deezerMoodQueries: ['melancholic indie rainy day', 'bittersweet piano', 'melancolie douce'],
      familyQueries: {
        TasteFamily.classical: ['chopin prelude op 28', 'tchaikovsky swan lake', 'schubert ave maria'],
        TasteFamily.chanson: ['serge gainsbourg la javanaise', 'charles aznavour la boheme', 'mylène farmer desenchantee'],
        TasteFamily.jazzSoul: ['amy winehouse back to black', 'nina simone feeling good', 'jeff buckley hallelujah'],
        TasteFamily.popRock: ['radiohead creep', 'lana del rey young and beautiful', 'the verve bittersweet symphony'],
        TasteFamily.rnb: ['the weeknd call out my name', 'frank ocean thinkin bout you', 'summer walker'],
        TasteFamily.hipHop: ['damso macarena', 'pnl au dd', 'kanye west heartless'],
        TasteFamily.afro: ['omah lay understand', 'fireboy dml peru acoustic', 'salif keita'],
        TasteFamily.electro: ['kavinsky nightcall', 'portishead glory box', 'massive attack teardrop'],
        TasteFamily.latinWorld: ['rosalia sakura', 'mon laferte tu falta de querer', 'soda stereo'],
      },
    ),
    MoodEmotionSpec(
      id: 'espoir',
      label: 'Espoir',
      bubbleColorHex: 0xFF56C271,
      valence: 0.80,
      energy: 0.62,
      deezerMoodQueries: ['hopeful inspiring anthem', 'uplifting sunrise music', 'espoir musique inspirante'],
      familyQueries: {
        TasteFamily.classical: ['beethoven ode to joy', 'hans zimmer time', 'debussy arabesque'],
        TasteFamily.chanson: ['jean jacques goldman je te donne', 'florent pagny savoir aimer', 'vianney beau papa'],
        TasteFamily.jazzSoul: ['nina simone feeling good', 'andrea bocelli time to say goodbye', 'bill withers lean on me'],
        TasteFamily.popRock: ['coldplay viva la vida', 'george harrison here comes the sun', 'sia unstoppable'],
        TasteFamily.rnb: ['john legend glory', 'alicia keys empire state of mind', 'labrinth'],
        TasteFamily.hipHop: ['kendrick lamar alright', 'j cole love yourz', 'orelsan la quete'],
        TasteFamily.afro: ['mercy chinwo', 'wizkid essence', 'sauti sol melanie'],
        TasteFamily.electro: ['avicii waiting for love', 'kygo higher love', 'coldplay a sky full of stars'],
        TasteFamily.latinWorld: ['diego torres color esperanza', 'juanes la camisa negra', 'mana'],
      },
    ),
    MoodEmotionSpec(
      id: 'colere',
      label: 'Colère',
      bubbleColorHex: 0xFFE63946,
      valence: 0.18,
      energy: 0.94,
      deezerMoodQueries: ['intense rock metal rage', 'aggressive powerful beat', 'intensity power workout'],
      familyQueries: {
        TasteFamily.classical: ['beethoven symphony 5', 'verdi dies irae requiem', 'prokofiev dance of the knights'],
        TasteFamily.chanson: ['noir desir le vent nous portera', 'orelsan basique', 'stromae ta fete'],
        TasteFamily.jazzSoul: ['nina simone sinnerman', 'rage against machine', 'james brown the payback'],
        TasteFamily.popRock: ['linkin park in the end', 'nirvana smells like teen spirit', 'imagine dragons believer'],
        TasteFamily.rnb: ['beyonce dont hurt yourself', 'rihanna bitch better have my money', 'sza kill bill'],
        TasteFamily.hipHop: ['eminem till i collapse', 'kendrick lamar dna', 'booba boulbi'],
        TasteFamily.afro: ['burna boy anybody', 'odumodublvck declan rice', 'black sherif kwaku the traveller'],
        TasteFamily.electro: ['the prodigy breathe', 'justice genesis', 'gesaffelstein'],
        TasteFamily.latinWorld: ['residente', 'calle 13 atrevete', 'shakira bzrp'],
      },
    ),
    MoodEmotionSpec(
      id: 'emerveillement',
      label: 'Émerveillement',
      bubbleColorHex: 0xFF38BDF8,
      valence: 0.84,
      energy: 0.56,
      deezerMoodQueries: ['cinematic orchestral wonder', 'dreamy ethereal masterpiece', 'majestic soundtrack'],
      familyQueries: {
        TasteFamily.classical: ['hans zimmer interstellar', 'vivaldi four seasons winter', 'claude debussy reverie'],
        TasteFamily.chanson: ['michel berger', 'lara fabian je t aime', 'celine dion my heart will go on'],
        TasteFamily.jazzSoul: ['ella fitzgerald dreamy', 'louis armstrong la vie en rose', 'michael buble feeling good'],
        TasteFamily.popRock: ['pink floyd shine on you crazy diamond', 'm83 midnight city', 'florence the machine dog days'],
        TasteFamily.rnb: ['frank ocean pyramids', 'fka twigs', 'alicia keys'],
        TasteFamily.hipHop: ['kanye west flashing lights', 'kid cudi pursuit of happiness', 'stromae formidable'],
        TasteFamily.afro: ['tems higher', 'richard bona muna', 'ckay emiliana'],
        TasteFamily.electro: ['m83 outro', 'daft punk touch', 'odesza a moment apart'],
        TasteFamily.latinWorld: ['ludovico einaudi experiencia', 'gustavo santaolalla', 'rodrigo y gabriela'],
      },
    ),
  ];

  static MoodEmotionSpec? findEmotionSpec(String rawLabel) {
    final norm = _normalize(rawLabel);
    for (final spec in moodEmotions) {
      if (_normalize(spec.label) == norm || spec.id == norm) {
        return spec;
      }
    }
    return null;
  }

  /// Construit le profil de goût strictement propre à un utilisateur.
  static UserTasteProfile buildProfile({
    required List<String> selectedArtists,
    required List<TrackModel> superlikedTracks,
    required List<TrackModel> favoriteTracks,
    required List<String> favoriteAlbumArtists,
    required List<Map<String, dynamic>> recentLocalEntries,
    required List<TrackModel> historyTracks,
    required List<String> searchedArtists,
  }) {
    final Map<String, String> canonicalNames = {};
    final Map<String, double> artistScores = {};
    final Map<TasteFamily, double> familyRaw = {};
    final Set<String> preferredIds = {};

    void addArtistSignal(String rawName, double weight) {
      final clean = rawName.trim();
      if (clean.isEmpty) return;
      final norm = _normalize(clean);
      if (norm.isEmpty || norm == 'artiste inconnu') return;
      canonicalNames.putIfAbsent(norm, () => clean);
      artistScores[norm] = (artistScores[norm] ?? 0.0) + weight;

      final family = classifyArtist(clean);
      if (family != null) {
        familyRaw[family] = (familyRaw[family] ?? 0.0) + weight;
      }
    }

    void addTrackSignal(TrackModel track, double weight) {
      if (track.id.isNotEmpty) preferredIds.add(track.id);
      addArtistSignal(track.artistName, weight);
      final titleFamily =
          classifyText('${track.artistName} ${track.title} ${track.albumName} ${track.genre}');
      if (titleFamily != null) {
        familyRaw[titleFamily] = (familyRaw[titleFamily] ?? 0.0) + (weight * 0.45);
      }
    }

    // 1. Artistes choisis par l'utilisateur (signal explicite le plus fort)
    for (final artist in selectedArtists) {
      addArtistSignal(artist, 3.6);
    }

    // 2. Superlikes Sonoritiz (goût très marqué)
    for (final track in superlikedTracks) {
      addTrackSignal(track, 3.0);
    }

    // 3. Favoris & albums favoris
    for (final track in favoriteTracks) {
      addTrackSignal(track, 2.2);
    }
    for (final artist in favoriteAlbumArtists) {
      addArtistSignal(artist, 2.0);
    }

    // 4. Écoutes récentes avec décroissance exponentielle (demi-vie = 7 jours)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final entry in recentLocalEntries) {
      final rawTrack = entry['track'];
      if (rawTrack is! Map) continue;
      final track = TrackModel.fromJson(Map<String, dynamic>.from(rawTrack));
      final int count = entry['recent_count'] is int ? entry['recent_count'] as int : 1;
      final int lastMs = entry['last_played_ms'] is int ? entry['last_played_ms'] as int : nowMs;
      final double daysAgo = math.max(0.0, (nowMs - lastMs) / 86400000.0);
      final double recencyDecay = math.exp(-daysAgo / 7.0);
      final double playWeight = (1.1 + 0.55 * math.log(1 + count)) * recencyDecay;
      addTrackSignal(track, playWeight);
    }

    // 5. Historique général de l'utilisateur
    for (var i = 0; i < historyTracks.length && i < 40; i++) {
      final decay = math.max(0.35, 1.0 - (i * 0.015));
      addTrackSignal(historyTracks[i], 0.9 * decay);
    }

    // 6. Recherches d'artistes récentes du compte
    for (final artist in searchedArtists.take(15)) {
      addArtistSignal(artist, 0.85);
    }

    // Remapping des clés normalisées vers leurs noms canoniques
    final Map<String, double> finalArtists = {};
    for (final e in artistScores.entries) {
      final name = canonicalNames[e.key] ?? e.key;
      finalArtists[name] = e.value;
    }

    // Normalisation de la distribution des familles de goût
    final double totalFamily = familyRaw.values.fold(0.0, (sum, v) => sum + v);
    final Map<TasteFamily, double> normalizedFamilies = {};
    if (totalFamily > 0) {
      for (final e in familyRaw.entries) {
        normalizedFamilies[e.key] = e.value / totalFamily;
      }
    }

    return UserTasteProfile(
      artistWeights: finalArtists,
      familyScores: normalizedFamilies,
      preferredTrackIds: preferredIds,
    );
  }

  /// Classe un artiste connu ou via heuristiques sémantiques dans une TasteFamily.
  static TasteFamily? classifyArtist(String rawArtist) {
    final norm = _normalize(rawArtist);
    if (norm.isEmpty) return null;

    final knownKey = ArtistsData.inferTasteFamilyKey(rawArtist);
    if (knownKey != null) {
      return _familyFromKey(knownKey);
    }
    return classifyText(norm);
  }

  static TasteFamily? classifyText(String raw) {
    final t = _normalize(raw);
    if (t.isEmpty) return null;

    const classicalKw = [
      'beethoven', 'mozart', 'chopin', 'bach', 'vivaldi', 'debussy', 'saties', 'satiel',
      'einaudi', 'richter', 'tiersen', 'zimmer', 'morricone', 'pavarotti', 'bocelli',
      'orchestr', 'symphon', 'concerto', 'sonat', 'nocturne', 'prelude', 'claire de lune',
      'adagio', 'requiem', 'philharmonic', 'piano solo', 'violin', 'cello', 'classique',
    ];
    const chansonKw = [
      'aznavour', 'piaf', 'brel', 'brassens', 'gainsbourg', 'goldman', 'hallyday',
      'celine dion', 'dalida', 'cabrel', 'souchon', 'pagny', 'kaas', 'bruel', 'farmer',
      'hardy', 'claude francois', 'michel sardou', 'renaud', 'vianney', 'clara luciani',
      'angele', 'zaz', 'stromae', 'indila', 'slimane', 'grand corps malade', 'chanson',
    ];
    const jazzSoulKw = [
      'sinatra', 'nina simone', 'fitzgerald', 'armstrong', 'miles davis', 'coltrane',
      'nat king cole', 'aretha', 'ray charles', 'marvin gaye', 'stevie wonder', 'otis redding',
      'norah jones', 'buble', 'gregory porter', 'bill withers', 'etta james', 'amy winehouse',
      'jazz', 'bossa nova', 'blues',
    ];
    const afroKw = [
      'burna boy', 'wizkid', 'davido', 'rema', 'asake', 'ayra starr', 'tems', 'fireboy',
      'ckay', 'omah lay', 'ruger', 'locko', 'charlotte dipanda', 'tenorr', 'tenor',
      'manu dibango', 'richard bona', 'koffi olomide', 'fally ipupa', 'youssou ndour',
      'salif keita', 'tyla', 'master kg', 'amapiano', 'afrobeat', 'makossa', 'bikutsi',
      'mbol', 'coup', 'ndombolo', 'cameroun', '237', 'ko-c', 'maahlox', 'minks', 'aphro',
    ];
    const hipHopKw = [
      'kendrick', 'drake', 'j cole', 'eminem', 'tupac', 'jay z', 'kanye', 'travis scott',
      'ninho', 'damso', 'booba', 'orelsan', 'pnl', 'nekfeu', 'jul ', 'niska', 'gazo',
      'tiakola', 'sch', 'kaaris', 'future', 'metro boomin', 'trap', 'drill', 'rap ',
    ];
    const rnbKw = [
      'beyonce', 'rihanna', 'chris brown', 'usher', 'sza', 'frank ocean', 'alicia keys',
      'summer walker', 'daniel caesar', 'tayc', 'dadju', 'sade', 'whitney houston',
      'maria carey', 'mariah carey', 'r&b',
    ];
    const electroKw = [
      'daft punk', 'david guetta', 'avicii', 'calvin harris', 'tiesto', 'martin garrix',
      'kygo', 'dj snake', 'petit biscuit', 'kavinsky', 'justice', 'kungs', 'odesza',
      'electro', 'house ', 'techno', 'edm',
    ];
    const popRockKw = [
      'queen', 'beatles', 'michael jackson', 'elton john', 'madonna', 'phil collins',
      'dire straits', 'u2', 'coldplay', 'adele', 'ed sheeran', 'taylor swift', 'bruno mars',
      'billie eilish', 'weeknd', 'dua lipa', 'harry styles', 'sia', 'imagine dragons',
      'pink floyd', 'linkin park', 'nirvana', 'elvis',
    ];

    if (_matchesAny(t, classicalKw)) return TasteFamily.classical;
    if (_matchesAny(t, chansonKw)) return TasteFamily.chanson;
    if (_matchesAny(t, jazzSoulKw)) return TasteFamily.jazzSoul;
    if (_matchesAny(t, afroKw)) return TasteFamily.afro;
    if (_matchesAny(t, hipHopKw)) return TasteFamily.hipHop;
    if (_matchesAny(t, rnbKw)) return TasteFamily.rnb;
    if (_matchesAny(t, electroKw)) return TasteFamily.electro;
    if (_matchesAny(t, popRockKw)) return TasteFamily.popRock;
    return null;
  }

  /// Filtre et ordonne des pistes candidates selon le profil actif avec pénalité stricte
  /// contre les genres incompatibles lorsque l'utilisateur a un profil bien défini.
  static List<TrackModel> rankTracksForProfile(
    List<TrackModel> candidates,
    UserTasteProfile profile, {
    int limit = 20,
    int maxPerArtist = 2,
    bool strictGate = true,
  }) {
    if (candidates.isEmpty) return [];

    final Map<String, double> normArtists = {
      for (final e in profile.artistWeights.entries) _normalize(e.key): e.value,
    };

    final scored = <_ScoredTrack>[];
    final Set<String> seenKeys = {};

    for (var i = 0; i < candidates.length; i++) {
      final track = candidates[i];
      if (track.title.trim().isEmpty || track.artistName.trim().isEmpty) continue;
      final dedupeKey =
          '${_normalize(track.title)}_${_normalize(track.artistName)}';
      if (!seenKeys.add(dedupeKey)) continue;

      double score = 1.0 - (i * 0.002);
      final normArtist = _normalize(track.artistName);

      // Correspondance directe ou partielle avec un artiste du profil
      for (final entry in normArtists.entries) {
        if (normArtist == entry.key ||
            normArtist.contains(entry.key) ||
            entry.key.contains(normArtist)) {
          score += entry.value * 1.4;
        }
      }

      // Correspondance par famille musicale + barrière stricte (ex: pas d'afro/trap pour un profil classique/chanson)
      final trackFamily =
          classifyText('${track.artistName} ${track.title} ${track.albumName} ${track.genre}');
      if (trackFamily != null && !profile.isColdStart) {
        final double userFamilyScore = profile.familyScores[trackFamily] ?? 0.0;
        if (userFamilyScore > 0) {
          score += userFamilyScore * 5.0;
        } else if (strictGate && profile.artistWeights.length >= 2) {
          // L'utilisateur a un profil établi et 0 affinité pour cette famille
          if (_isIncompatibleFamily(profile, trackFamily)) {
            continue;
          }
          score -= 3.5;
        }
      }

      scored.add(_ScoredTrack(track: track, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Réordonnancement diversifié (MMR-like cap par artiste)
    final List<TrackModel> result = [];
    final Map<String, int> artistCount = {};
    for (final item in scored) {
      final aKey = _normalize(item.track.artistName);
      final count = artistCount[aKey] ?? 0;
      if (count >= maxPerArtist) continue;
      artistCount[aKey] = count + 1;
      result.add(item.track);
      if (result.length >= limit) break;
    }

    return result;
  }

  /// Détermine si un genre est fondamentalement discordant par rapport aux goûts actifs.
  static bool _isIncompatibleFamily(
    UserTasteProfile profile,
    TasteFamily candidateFamily,
  ) {
    if ((profile.familyScores[candidateFamily] ?? 0.0) > 0.01) return false;

    final classicalAndChanson = (profile.familyScores[TasteFamily.classical] ?? 0.0) +
        (profile.familyScores[TasteFamily.chanson] ?? 0.0) +
        (profile.familyScores[TasteFamily.jazzSoul] ?? 0.0);

    // Un amateur de classique / chanson / jazz sans aucune écoute Afro ou Rap ne reçoit jamais ça
    if (classicalAndChanson >= 0.45 &&
        (candidateFamily == TasteFamily.afro ||
            candidateFamily == TasteFamily.hipHop ||
            candidateFamily == TasteFamily.electro)) {
      return true;
    }
    return false;
  }

  /// Construit les requêtes Deezer intelligentes pour 1 à 3 émotions + profil de l'utilisateur.
  static List<String> buildEmotionQueries({
    required List<String> selectedEmotions,
    required UserTasteProfile profile,
  }) {
    final specs = selectedEmotions
        .map(findEmotionSpec)
        .whereType<MoodEmotionSpec>()
        .toList();
    if (specs.isEmpty) return ['top soothing music'];

    final List<String> queries = [];
    final families = profile.isColdStart
        ? <TasteFamily>[TasteFamily.popRock, TasteFamily.chanson, TasteFamily.jazzSoul, TasteFamily.rnb]
        : profile.dominantFamilies.take(3).toList();

    for (final spec in specs) {
      // 1. Combiner l'émotion avec les familles dominantes de l'utilisateur
      for (final family in families) {
        final fQueries = spec.familyQueries[family];
        if (fQueries != null && fQueries.isNotEmpty) {
          queries.addAll(fQueries.take(2));
        }
      }
      // 2. Associer les artistes phares du compte à l'émotion (si disponibles)
      if (profile.topAnchorArtists.isNotEmpty) {
        final anchor = profile.topAnchorArtists.first;
        queries.add('$anchor ${spec.label.toLowerCase()}');
      }
      // 3. Fallback générique cohérent uniquement si le profil est neuf
      if (profile.isColdStart) {
        queries.addAll(spec.deezerMoodQueries.take(2));
      }
    }

    return queries.toSet().toList();
  }

  static TasteFamily? _familyFromKey(String key) {
    switch (key) {
      case 'classical':
        return TasteFamily.classical;
      case 'chanson':
        return TasteFamily.chanson;
      case 'jazzSoul':
        return TasteFamily.jazzSoul;
      case 'popRock':
        return TasteFamily.popRock;
      case 'rnb':
        return TasteFamily.rnb;
      case 'hipHop':
        return TasteFamily.hipHop;
      case 'afro':
        return TasteFamily.afro;
      case 'electro':
        return TasteFamily.electro;
      case 'latinWorld':
        return TasteFamily.latinWorld;
      default:
        return null;
    }
  }

  static bool _matchesAny(String haystack, List<String> needles) {
    for (final n in needles) {
      if (haystack.contains(n)) return true;
    }
    return false;
  }

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ô', 'o')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('’', '\'')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _ScoredTrack {
  final TrackModel track;
  final double score;
  const _ScoredTrack({required this.track, required this.score});
}
