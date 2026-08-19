import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../player/presentation/cubit/player_cubit.dart';

/// Liste de pistes populaires mondiales avec leur ID YouTube rÃ©el.
/// Cela Ã©vite totalement les appels rÃ©seau pour charger la liste du quiz.
class _QuizTrackData {
  final String id;
  final String title;
  final String artist;

  const _QuizTrackData({required this.id, required this.title, required this.artist});
}

const List<_QuizTrackData> _popularTracks = [
  // === HITS INTERNATIONAUX ===
  _QuizTrackData(id: 'kJQP7kiw5Fk', title: 'Despacito', artist: 'Luis Fonsi'),
  _QuizTrackData(id: 'RgKAFK5djSk', title: 'See You Again', artist: 'Wiz Khalifa'),
  _QuizTrackData(id: 'JGwWNGJdvx8', title: 'Shape of You', artist: 'Ed Sheeran'),
  _QuizTrackData(id: 'OPf0YbXqDm0', title: 'Uptown Funk', artist: 'Bruno Mars'),
  _QuizTrackData(id: 'fRh_vgS2dFE', title: 'Sorry', artist: 'Justin Bieber'),
  _QuizTrackData(id: 'CevxZvSJLk8', title: 'Roar', artist: 'Katy Perry'),
  _QuizTrackData(id: 'bo_efYhYU2A', title: 'Faded', artist: 'Alan Walker'),
  _QuizTrackData(id: '09R8_2nJtjg', title: 'Sugar', artist: 'Maroon 5'),
  _QuizTrackData(id: 'YqeW9_5kURI', title: 'All of Me', artist: 'John Legend'),
  _QuizTrackData(id: 'SlPhMPnQ58k', title: 'Waka Waka', artist: 'Shakira'),
  _QuizTrackData(id: 'e-ORhEE9VVg', title: 'Blank Space', artist: 'Taylor Swift'),
  _QuizTrackData(id: 'hLQl3WQQoQ0', title: 'Someone Like You', artist: 'Adele'),
  _QuizTrackData(id: 'pRpeEdMmmQ0', title: 'Shake It Off', artist: 'Taylor Swift'),
  _QuizTrackData(id: 'nfs8NYg7yQM', title: 'Perfect', artist: 'Ed Sheeran'),
  _QuizTrackData(id: 'lp-EO5I60KA', title: 'Counting Stars', artist: 'OneRepublic'),
  _QuizTrackData(id: '60ItHLz5WEA', title: 'Hello', artist: 'Adele'),
  _QuizTrackData(id: 'QYh6mYIJG2Y', title: 'Let Her Go', artist: 'Passenger'),
  _QuizTrackData(id: 'HP-MbfHFUqs', title: 'Thunder', artist: 'Imagine Dragons'),
  _QuizTrackData(id: 'ktvTqknDobU', title: 'Radioactive', artist: 'Imagine Dragons'),
  _QuizTrackData(id: 'YBHQbu5rbdQ', title: 'Fix You', artist: 'Coldplay'),
  _QuizTrackData(id: 'IcrbM1l_BoI', title: 'Closer', artist: 'The Chainsmokers'),
  _QuizTrackData(id: 'ru0K8uYEZWw', title: 'Thinking Out Loud', artist: 'Ed Sheeran'),
  _QuizTrackData(id: '7wtfhZwyrcc', title: 'Happier', artist: 'Marshmello'),
  _QuizTrackData(id: 'DyDfgMOUjCI', title: 'Blinding Lights', artist: 'The Weeknd'),
  _QuizTrackData(id: 'RBumgq5yVrA', title: 'Photograph', artist: 'Ed Sheeran'),
  _QuizTrackData(id: 'hT_nvWreIhg', title: 'Cheap Thrills', artist: 'Sia'),
  _QuizTrackData(id: 'pXRviuL6vMY', title: 'Attention', artist: 'Charlie Puth'),
  _QuizTrackData(id: 'lWA2pjMjpBs', title: 'Rockabye', artist: 'Clean Bandit'),
  _QuizTrackData(id: '450p7goxZqg', title: 'Dark Horse', artist: 'Katy Perry'),
  _QuizTrackData(id: 'pt8VYOfr8To', title: 'Firework', artist: 'Katy Perry'),
  // 31-60
  _QuizTrackData(id: 'YQHsXMglC9A', title: 'Hello', artist: 'Adele'),
  _QuizTrackData(id: 'lY2yjAdbvdQ', title: 'Havana', artist: 'Camila Cabello'),
  _QuizTrackData(id: 'iS1g8G_njx8', title: 'Chandelier', artist: 'Sia'),
  _QuizTrackData(id: 'sc4OxO5p2pg', title: 'Believer', artist: 'Imagine Dragons'),
  _QuizTrackData(id: 'QpbQ4I3Eidg', title: 'Bad Guy', artist: 'Billie Eilish'),
  _QuizTrackData(id: 'kXYiU_JCYtU', title: 'Numb', artist: 'Linkin Park'),
  _QuizTrackData(id: 'k4V3Mo61fJM', title: 'Old Town Road', artist: 'Lil Nas X'),
  _QuizTrackData(id: 'LjhCEhWiKXk', title: 'Dance Monkey', artist: 'Tones and I'),
  _QuizTrackData(id: 'uelHwf8o7_U', title: 'Love Yourself', artist: 'Justin Bieber'),
  _QuizTrackData(id: 'hHUbLv4ThOo', title: 'Chained to the Rhythm', artist: 'Katy Perry'),
  _QuizTrackData(id: 'ApXoWvfEYVU', title: 'Stay', artist: 'The Kid LAROI'),
  _QuizTrackData(id: 'dq46WUEJMlY', title: 'Starboy', artist: 'The Weeknd'),
  _QuizTrackData(id: 'RgKAFK5djSk', title: 'See You Again', artist: 'Charlie Puth'),
  _QuizTrackData(id: '5GL9JoH4Sws', title: 'Stitches', artist: 'Shawn Mendes'),
  _QuizTrackData(id: 'SiAuAJBZuGs', title: 'Gangnam Style', artist: 'PSY'),
  _QuizTrackData(id: 'fJ9rUzIMcZQ', title: 'Bohemian Rhapsody', artist: 'Queen'),
  _QuizTrackData(id: 'Zi_XLOBDo_Y', title: 'Billie Jean', artist: 'Michael Jackson'),
  _QuizTrackData(id: 'dTa2Bzlbjv0', title: 'Save Your Tears', artist: 'The Weeknd'),
  _QuizTrackData(id: 'KQ6zr6kCPj8', title: 'GOAT', artist: 'Polyphia'),
  _QuizTrackData(id: 'bt-RoSzsEKA', title: 'Levitating', artist: 'Dua Lipa'),
  _QuizTrackData(id: 'TUVcZfQe-Kw', title: 'Watermelon Sugar', artist: 'Harry Styles'),
  _QuizTrackData(id: 'FuXNumBwDOM', title: 'Peaches', artist: 'Justin Bieber'),
  _QuizTrackData(id: 'mRD0-GxKnBc', title: 'As It Was', artist: 'Harry Styles'),
  _QuizTrackData(id: '39LLpOezpmo', title: 'New Rules', artist: 'Dua Lipa'),
  _QuizTrackData(id: 'oygrmJFKYZY', title: 'Heathens', artist: 'Twenty One Pilots'),
  _QuizTrackData(id: 'Pkh8UtuejGw', title: 'Savage Love', artist: 'Jawsh 685'),
  _QuizTrackData(id: '2Vv-BfVoq4g', title: 'Perfect Duet', artist: 'Ed Sheeran'),
  _QuizTrackData(id: 'WpYeekQkAdc', title: 'Everything I Wanted', artist: 'Billie Eilish'),
  _QuizTrackData(id: 'PIh2xe4jnpk', title: 'Easy On Me', artist: 'Adele'),
  _QuizTrackData(id: 'kTJczUoc26U', title: 'Say So', artist: 'Doja Cat'),
  // 61-100
  _QuizTrackData(id: 'RlPNh_PBZb4', title: 'Lovely', artist: 'Billie Eilish'),
  _QuizTrackData(id: 'dhYOPzcsbGM', title: 'Positions', artist: 'Ariana Grande'),
  _QuizTrackData(id: 'QYh6mYIJG2Y', title: 'Let Her Go', artist: 'Passenger'),
  _QuizTrackData(id: 'aJOTlE1K90k', title: 'Side to Side', artist: 'Ariana Grande'),
  _QuizTrackData(id: 'psuRGfAaju4', title: 'Sunflower', artist: 'Post Malone'),
  _QuizTrackData(id: 'PT2_F-1esPk', title: 'Circles', artist: 'Post Malone'),
  _QuizTrackData(id: 'U05fwua9-D4', title: 'Flowers', artist: 'Miley Cyrus'),
  _QuizTrackData(id: 'papuvlVeZg8', title: 'Kill Bill', artist: 'SZA'),
  _QuizTrackData(id: 'ZbZSe6N_BXs', title: 'Happy', artist: 'Pharrell Williams'),
  _QuizTrackData(id: '0yW7w8F2TVA', title: 'Unstoppable', artist: 'Sia'),
  _QuizTrackData(id: 'nYh-n7EOtMA', title: 'Somebody That I Used To Know', artist: 'Gotye'),
  _QuizTrackData(id: '1k8craCGpgs', title: 'Right Now', artist: 'Rihanna'),
  _QuizTrackData(id: '7PCkvCPvDXk', title: 'A Thousand Years', artist: 'Christina Perri'),
  _QuizTrackData(id: 'YnwsMEabmSo', title: 'Ride', artist: 'Twenty One Pilots'),
  _QuizTrackData(id: 'moSFlvxnbgk', title: 'Let Me Love You', artist: 'DJ Snake'),
  _QuizTrackData(id: '0KSOMA3QBU0', title: 'Dark Side', artist: 'Alan Walker'),
  _QuizTrackData(id: 'k2qgadSvNyU', title: 'Treat You Better', artist: 'Shawn Mendes'),
  _QuizTrackData(id: '7maJOI3QMu0', title: 'Wolves', artist: 'Selena Gomez'),
  _QuizTrackData(id: '2zNSgSzhBfM', title: 'Lucid Dreams', artist: 'Juice WRLD'),
  _QuizTrackData(id: 'yzTuBuRdAyA', title: 'The Lazy Song', artist: 'Bruno Mars'),
  _QuizTrackData(id: 'QcIy9NiNbmo', title: 'Take Me To Church', artist: 'Hozier'),
  _QuizTrackData(id: 'nSDgHBxUbVQ', title: 'Video Games', artist: 'Lana Del Rey'),
  _QuizTrackData(id: 'kOHB85vDuow', title: 'West Coast', artist: 'Lana Del Rey'),
  _QuizTrackData(id: 'OPf0YbXqDm0', title: 'Uptown Funk', artist: 'Mark Ronson'),
  _QuizTrackData(id: 'gCYcHz2k5x0', title: 'Mad World', artist: 'Gary Jules'),
  _QuizTrackData(id: 'tg00YEETFzg', title: 'We Are The Champions', artist: 'Queen'),
  _QuizTrackData(id: 'btPJPFnesV4', title: 'Eye of the Tiger', artist: 'Survivor'),
  _QuizTrackData(id: 'Dsp_8Lm1eSk', title: 'Livin on a Prayer', artist: 'Bon Jovi'),
  _QuizTrackData(id: 'pAgnJDJN4VA', title: 'Back In Black', artist: 'AC/DC'),
  _QuizTrackData(id: '1w7OgIMMRc4', title: 'Sweet Child O Mine', artist: 'Guns N Roses'),
  _QuizTrackData(id: 'lDK9QqIzhwk', title: 'November Rain', artist: 'Guns N Roses'),
  _QuizTrackData(id: 'hTWKbfoikeg', title: 'Smells Like Teen Spirit', artist: 'Nirvana'),
  _QuizTrackData(id: 'bx1Bh8ZvH84', title: 'Lose Yourself', artist: 'Eminem'),
  _QuizTrackData(id: 'uelHwf8o7_U', title: 'Love Yourself', artist: 'Justin Bieber'),
  _QuizTrackData(id: 'e82VE8UtW8A', title: 'Crazy In Love', artist: 'Beyonce'),
  _QuizTrackData(id: 'osdoLjUNFnA', title: 'Diamonds', artist: 'Rihanna'),
  _QuizTrackData(id: 'CvBfHwUxHIk', title: 'Umbrella', artist: 'Rihanna'),
  _QuizTrackData(id: 'lWA2pjMjpBs', title: 'Rockabye', artist: 'Clean Bandit'),
  _QuizTrackData(id: 'tCXGJQYZ9JA', title: 'Locked Out Of Heaven', artist: 'Bruno Mars'),
  _QuizTrackData(id: 'OGBv6KubtVs', title: 'Without Me', artist: 'Halsey'),
  // 101-150
  _QuizTrackData(id: 'foE1mO2yM04', title: 'Take On Me', artist: 'a-ha'),
  _QuizTrackData(id: 'iPUmE-tne5U', title: 'Lose Control', artist: 'Teddy Swims'),
  _QuizTrackData(id: 'V1Pl8CzNzCw', title: 'Titanium', artist: 'David Guetta'),
  _QuizTrackData(id: 'YR5ApYxkU-U', title: 'Toxic', artist: 'Britney Spears'),
  _QuizTrackData(id: 'CGyEd0aKWZE', title: 'Pumped Up Kicks', artist: 'Foster The People'),
  _QuizTrackData(id: 'rYEDA3JcQqw', title: 'Rolling in the Deep', artist: 'Adele'),
  _QuizTrackData(id: 'sOnqjkJTMaA', title: 'Thriller', artist: 'Michael Jackson'),
  _QuizTrackData(id: 'oRdxUFDoQe0', title: 'Break Free', artist: 'Ariana Grande'),
  _QuizTrackData(id: 'QJO3ROT-A4E', title: 'Get Lucky', artist: 'Daft Punk'),
  _QuizTrackData(id: 'gCYcHz2k5x0', title: 'Mad World', artist: 'Gary Jules'),
  _QuizTrackData(id: 'HCjNJDNzw8Y', title: 'Work From Home', artist: 'Fifth Harmony'),
  _QuizTrackData(id: 'SYM-RJwSGQ8', title: 'Can I Have This Dance', artist: 'High School Musical'),
  _QuizTrackData(id: 'euCqAq6BRQg', title: 'Demons', artist: 'Imagine Dragons'),
  _QuizTrackData(id: 'YykjpeuMNEk', title: 'Alone', artist: 'Alan Walker'),
  _QuizTrackData(id: 'k2C5TjS2sh4', title: 'Astronaut In The Ocean', artist: 'Masked Wolf'),
  _QuizTrackData(id: 'izGwDsrQ1eQ', title: 'Energy', artist: 'Beyonce'),
  _QuizTrackData(id: 'lbbhQWmllzs', title: 'Take It Easy', artist: 'Eagles'),
  _QuizTrackData(id: 'W-TE_Ys4iwM', title: 'Girls Like You', artist: 'Maroon 5'),
  _QuizTrackData(id: '60ItHLz5WEA', title: 'Hello', artist: 'Adele'),
  _QuizTrackData(id: 'lDK9QqIzhwk', title: 'November Rain', artist: 'Guns N Roses'),
  _QuizTrackData(id: 'HyHNuVaZJ-k', title: 'Feel Good Inc.', artist: 'Gorillaz'),
  _QuizTrackData(id: 'bpOSxM0rNPM', title: 'Call Me Maybe', artist: 'Carly Rae Jepsen'),
  _QuizTrackData(id: 'KRaWnd3LJfs', title: 'Dusk Till Dawn', artist: 'Zayn'),
  _QuizTrackData(id: 'sVx1mJDeUjY', title: 'I Gotta Feeling', artist: 'Black Eyed Peas'),
  _QuizTrackData(id: 'WA4iX5D9Z64', title: 'Somebody Else', artist: 'The 1975'),
  _QuizTrackData(id: 'F90Cw4l-8NY', title: 'Dynamite', artist: 'BTS'),
  _QuizTrackData(id: 'gdZLi9oWNZg', title: 'Butter', artist: 'BTS'),
  _QuizTrackData(id: '46Cfrl7hMoQ', title: 'How You Like That', artist: 'BLACKPINK'),
  _QuizTrackData(id: 'UhxW2KJMCuo', title: 'DDU-DU DDU-DU', artist: 'BLACKPINK'),
  _QuizTrackData(id: 'om_HuhbYHSs', title: 'Hips Dont Lie', artist: 'Shakira'),
  _QuizTrackData(id: 'XYBUAmdBbsQ', title: 'Without Me', artist: 'Eminem'),
  _QuizTrackData(id: '6Ejga4kJUts', title: 'Stan', artist: 'Eminem'),
  _QuizTrackData(id: 'hnpILIIo9ek', title: 'Mockingbird', artist: 'Eminem'),
  _QuizTrackData(id: 'N4d7Wp9kKjA', title: 'Paradise', artist: 'Coldplay'),
  _QuizTrackData(id: 'dvgZkm1xWPE', title: 'Viva La Vida', artist: 'Coldplay'),
  _QuizTrackData(id: 'RvA3q0ZU-NQ', title: 'Yellow', artist: 'Coldplay'),
  _QuizTrackData(id: 'QtXby3twMmI', title: 'A Sky Full of Stars', artist: 'Coldplay'),
  _QuizTrackData(id: '1-xGerv5FOk', title: 'Hymn for the Weekend', artist: 'Coldplay'),
  _QuizTrackData(id: 'k4V3Mo61fJM', title: 'Old Town Road', artist: 'Lil Nas X'),
  _QuizTrackData(id: '6BYFSPR60F4', title: 'MONTERO', artist: 'Lil Nas X'),
  // === FRANCOPHONE ===
  // 151-200
  _QuizTrackData(id: 'oiKj0Z_Xnjc', title: 'Papaoutai', artist: 'Stromae'),
  _QuizTrackData(id: 'UKftOH54iNU', title: 'Formidable', artist: 'Stromae'),
  _QuizTrackData(id: 'eXTO_JfVhjQ', title: 'Alors On Danse', artist: 'Stromae'),
  _QuizTrackData(id: 'S_xH7noaqTA', title: 'Tous Les Memes', artist: 'Stromae'),
  _QuizTrackData(id: 'bM7SZ5SBzyY', title: 'Derniere Danse', artist: 'Indila'),
  _QuizTrackData(id: '3O1_3zBUKM8', title: 'Djadja', artist: 'Aya Nakamura'),
  _QuizTrackData(id: 'qlR0fZPsJSs', title: 'Pookie', artist: 'Aya Nakamura'),
  _QuizTrackData(id: 'hiGFkR7DIzA', title: 'Copines', artist: 'Aya Nakamura'),
  _QuizTrackData(id: 'BRQqEvlKAfk', title: 'Love Nwantiti', artist: 'CKay'),
  _QuizTrackData(id: 'rqHDFw36M0U', title: 'Ramenez La Coupe', artist: 'Vegedream'),
  _QuizTrackData(id: 'FzOrzJ1dNMk', title: 'Coeur Noir', artist: 'Eva'),
  _QuizTrackData(id: 'dYRs7Q1DjT4', title: 'Ocean', artist: 'Karol G'),
  _QuizTrackData(id: 'AzGKY_7-Rbo', title: 'Reine', artist: 'Dadju'),
  _QuizTrackData(id: 'rSpqOmvQJXg', title: 'Mwaka Moon', artist: 'Kalash'),
  _QuizTrackData(id: 'iPGgnzc34tY', title: 'Je Suis', artist: 'Bigflo et Oli'),
  _QuizTrackData(id: 'K5KAc5CoCuk', title: 'Dommage', artist: 'Bigflo et Oli'),
  _QuizTrackData(id: 'gyN14du-FjA', title: 'Andalouse', artist: 'Kendji Girac'),
  _QuizTrackData(id: '59Q_lhgGANc', title: 'Color Gitano', artist: 'Kendji Girac'),
  _QuizTrackData(id: 'qnP2p4K3mlA', title: 'Bella', artist: 'Maitre Gims'),
  _QuizTrackData(id: '6TpyRE_juyA', title: 'Sappes Comme Jamais', artist: 'Maitre Gims'),
  _QuizTrackData(id: 'RKmw2oqdmew', title: 'Est-Ce Que Tu Maimes', artist: 'Maitre Gims'),
  _QuizTrackData(id: 'ithDBal3RQ4', title: 'Le Matin', artist: 'Gims'),
  _QuizTrackData(id: 'vjLz3pgSiJ0', title: 'On Ecrit Sur Les Murs', artist: 'Kids United'),
  _QuizTrackData(id: 'fNFzfwLM72c', title: 'Tout Oublier', artist: 'Angele'),
  _QuizTrackData(id: 'XqMOF0oY1IE', title: 'Balance Ton Quoi', artist: 'Angele'),
  _QuizTrackData(id: 'wyzJ2WUON5o', title: 'Fever', artist: 'Angele'),
  _QuizTrackData(id: 'gz7uMZVLl-g', title: 'Bruxelles Je Taime', artist: 'Angele'),
  _QuizTrackData(id: 'tTmGVMmK3Ew', title: 'Laissez-Moi Danser', artist: 'Dalida'),
  _QuizTrackData(id: '2MsOpY5xUbs', title: 'Moustache', artist: 'Dalida'),
  _QuizTrackData(id: 'RLaO-jZS1ts', title: 'GPS', artist: 'Jul'),
  // 201-250
  _QuizTrackData(id: 'v0SlgVEFd5w', title: 'La Meme', artist: 'Maitre Gims'),
  _QuizTrackData(id: '-ObdvMkCKws', title: 'Ciao Adios', artist: 'Anne-Marie'),
  _QuizTrackData(id: 'oHg5SJYRHA0', title: 'Never Gonna Give You Up', artist: 'Rick Astley'),
  _QuizTrackData(id: 'dQw4w9WgXcQ', title: 'Never Gonna Give You Up', artist: 'Rick Astley'),
  _QuizTrackData(id: 'VbfpW0pbvaU', title: 'Breathe Me', artist: 'Sia'),
  _QuizTrackData(id: '2vjPBrBU-TM', title: 'Elastic Heart', artist: 'Sia'),
  _QuizTrackData(id: 'b4Bj7Zb-YD4', title: 'Habits', artist: 'Tove Lo'),
  _QuizTrackData(id: 'KEI4qSrkPAs', title: 'On My Way', artist: 'Alan Walker'),
  _QuizTrackData(id: 'sGkh1W5cbH4', title: 'Lily', artist: 'Alan Walker'),
  _QuizTrackData(id: 'uxpDa-c-4Mc', title: 'Stereo Hearts', artist: 'Gym Class Heroes'),
  _QuizTrackData(id: 'k-ImCpNqbJw', title: 'Good Feeling', artist: 'Flo Rida'),
  _QuizTrackData(id: 'pB-5XG-DbAA', title: 'On The Floor', artist: 'Jennifer Lopez'),
  _QuizTrackData(id: 'nsDwItoAqaM', title: 'Mi Gente', artist: 'J Balvin'),
  _QuizTrackData(id: 'kYtGl1dewv0', title: 'Taki Taki', artist: 'DJ Snake'),
  _QuizTrackData(id: 'DWcJFNfaw9c', title: 'Loca', artist: 'Shakira'),
  _QuizTrackData(id: 'gNi_6U5Pm_o', title: 'Swalla', artist: 'Jason Derulo'),
  _QuizTrackData(id: 'tcYodQoapMg', title: 'Lean On', artist: 'Major Lazer'),
  _QuizTrackData(id: 'YnwfTHpnGLY', title: 'Clarity', artist: 'Zedd'),
  _QuizTrackData(id: 'IxxstCcJlsc', title: 'The Middle', artist: 'Zedd'),
  _QuizTrackData(id: 'J_ub7Etch2U', title: 'Play Date', artist: 'Melanie Martinez'),
  _QuizTrackData(id: 'a7SouU3ECpU', title: 'Paris', artist: 'The Chainsmokers'),
  _QuizTrackData(id: 'FM7MFYoylVs', title: 'Something Just Like This', artist: 'The Chainsmokers'),
  _QuizTrackData(id: 'mWRsgZuwf_8', title: 'Dont Start Now', artist: 'Dua Lipa'),
  _QuizTrackData(id: 'oygrmJFKYZY', title: 'Heathens', artist: 'Twenty One Pilots'),
  _QuizTrackData(id: 'sRhTeaa_B98', title: 'Stressed Out', artist: 'Twenty One Pilots'),
  _QuizTrackData(id: 'tQ0yjYUFKAE', title: 'Talk', artist: 'Khalid'),
  _QuizTrackData(id: 'IPXIgEAGe4U', title: 'Lovely', artist: 'Khalid'),
  _QuizTrackData(id: 'LHCob76kigA', title: 'STAY', artist: 'The Kid LAROI'),
  _QuizTrackData(id: 'kdemFfbS5H0', title: 'Night Changes', artist: 'One Direction'),
  _QuizTrackData(id: 'QJO3ROT-A4E', title: 'Get Lucky', artist: 'Daft Punk'),
  // 251-300
  _QuizTrackData(id: 'y6120QOlsfU', title: 'Sandstorm', artist: 'Darude'),
  _QuizTrackData(id: 'fLexgOxsZu0', title: 'Harder Better Faster', artist: 'Daft Punk'),
  _QuizTrackData(id: 'WcIcVapfqXw', title: 'Summertime Sadness', artist: 'Lana Del Rey'),
  _QuizTrackData(id: 'gCrmFbgT37I', title: 'Grenade', artist: 'Bruno Mars'),
  _QuizTrackData(id: 'QK8mJJJvaes', title: 'Just The Way You Are', artist: 'Bruno Mars'),
  _QuizTrackData(id: 'OGBv6KubtVs', title: 'Without Me', artist: 'Halsey'),
  _QuizTrackData(id: 'pok8H_KF1FA', title: 'Eastside', artist: 'Benny Blanco'),
  _QuizTrackData(id: '0zGcUoRlhmw', title: 'Location', artist: 'Khalid'),
  _QuizTrackData(id: 'n1WpP7iowLc', title: 'Stressed Out', artist: 'Twenty One Pilots'),
  _QuizTrackData(id: 'kOkQ4T5WO9E', title: 'Now Or Never', artist: 'Halsey'),
  _QuizTrackData(id: 'ShlW5plD_40', title: 'Dont Wanna Know', artist: 'Maroon 5'),
  _QuizTrackData(id: 'aEb5gNsmGJ8', title: 'Calm Down', artist: 'Rema'),
  _QuizTrackData(id: 'VrR4EPBpEE0', title: 'Calm Down Remix', artist: 'Rema ft. Selena Gomez'),
  _QuizTrackData(id: 'LIjDYXOVcIY', title: 'Malibu', artist: 'Miley Cyrus'),
  _QuizTrackData(id: 'Q0oIoR9mLwc', title: 'Dark Side', artist: 'Kelly Clarkson'),
  _QuizTrackData(id: 'xTlNMmZKwpA', title: 'Wrecking Ball', artist: 'Miley Cyrus'),
  _QuizTrackData(id: 'CX11yw6YL1w', title: 'One Kiss', artist: 'Calvin Harris'),
  _QuizTrackData(id: '7nJRGARveVc', title: 'Memories', artist: 'Maroon 5'),
  _QuizTrackData(id: 'o_v9MY_FMcw', title: 'Wake Me Up', artist: 'Avicii'),
  _QuizTrackData(id: 'IcrbM1l_BoI', title: 'Closer', artist: 'The Chainsmokers'),
  _QuizTrackData(id: '1Cw1ng75KP0', title: 'Thank U Next', artist: 'Ariana Grande'),
  _QuizTrackData(id: 'SXiSVQZLje8', title: '7 Rings', artist: 'Ariana Grande'),
  _QuizTrackData(id: 'QYh6mYIJG2Y', title: 'Problem', artist: 'Ariana Grande'),
  _QuizTrackData(id: 'ffxKSjUwKdU', title: 'No Tears Left To Cry', artist: 'Ariana Grande'),
  _QuizTrackData(id: 'lWA2pjMjpBs', title: 'Rockabye', artist: 'Clean Bandit'),
  _QuizTrackData(id: 'Fe93CLbHjxQ', title: 'My Heart Will Go On', artist: 'Celine Dion'),
  _QuizTrackData(id: '3AtDnEC4zak', title: 'We Dont Talk Anymore', artist: 'Charlie Puth'),
  _QuizTrackData(id: 'ekzHIouo8Q4', title: 'River', artist: 'Eminem ft. Ed Sheeran'),
  _QuizTrackData(id: 'RsEZmictANA', title: 'Suga Suga', artist: 'Baby Bash'),
  _QuizTrackData(id: 'fKopy74weus', title: 'Sia Chandelier', artist: 'Sia'),
  _QuizTrackData(id: 'oHg5SJYRHA0', title: 'Last Friday Night', artist: 'Katy Perry'),
  _QuizTrackData(id: 'n8X9_MgEdCg', title: 'Holiday', artist: 'Green Day'),
  _QuizTrackData(id: 'dhYOPzcsbGM', title: 'Positions', artist: 'Ariana Grande'),
  _QuizTrackData(id: 'hBkMHjFDMFo', title: 'Jolie Nana', artist: 'Aya Nakamura'),
  _QuizTrackData(id: 'mYq5GclkWVo', title: 'La Dot', artist: 'Aya Nakamura'),
  _QuizTrackData(id: 'pNdO95XfJ8I', title: 'Ratata', artist: 'Stromae'),
  _QuizTrackData(id: 'wXhTHyIgQ_U', title: 'Carmen', artist: 'Stromae'),
  _QuizTrackData(id: 'nKhN1t_7PEY', title: 'Mon Amour', artist: 'Stromae'),
  _QuizTrackData(id: 'Lrle0x_DHBM', title: 'Tourner Dans Le Vide', artist: 'Indila'),
  _QuizTrackData(id: 'qgDCM91f7NY', title: 'SOS', artist: 'Indila'),
];

class QuizScreen extends StatefulWidget {
  const QuizScreen({Key? key}) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();

  List<_QuizTrackData> _quizTracks = [];
  List<_QuizTrackData> _poolTracks = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _isAnswered = false;
  String? _selectedOption;
  String _errorMessage = '';

  late String _correctAnswer;
  List<String> _options = [];
  late bool _askForArtist;

  Timer? _countdownTimer;
  int _timeLeft = 15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayerCubit>().pause();
    });
    _loadQuizData();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _yt.close();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _loadQuizData() {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Pas d'appel rÃ©seau pour charger les pistes, tout est local !
    final allTracks = List<_QuizTrackData>.from(_popularTracks);
    allTracks.shuffle();

    _poolTracks = allTracks;
    _quizTracks = allTracks.take(10).toList();
    _currentQuestionIndex = 0;
    _score = 0;

    _prepareQuestion();
  }

  Future<void> _prepareQuestion() async {
    if (_currentQuestionIndex >= 10) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _isAnswered = false;
      _selectedOption = null;
      _timeLeft = 30;
      _errorMessage = '';
    });

    final currentTrack = _quizTracks[_currentQuestionIndex];

    // MÃ©lange Titre / Artiste (alÃ©atoire)
    _askForArtist = Random().nextBool();
    _correctAnswer = _askForArtist ? currentTrack.artist : currentTrack.title;

    // GÃ©nÃ©rer 3 mauvaises options
    final Set<String> wrongOptions = {};
    final shuffledPool = List<_QuizTrackData>.from(_poolTracks)..shuffle();

    for (var t in shuffledPool) {
      if (t.id == currentTrack.id) continue;
      final wrong = _askForArtist ? t.artist : t.title;
      if (wrong.isNotEmpty && wrong != _correctAnswer) {
        wrongOptions.add(wrong);
      }
      if (wrongOptions.length >= 3) break;
    }

    _options = wrongOptions.toList();
    _options.add(_correctAnswer);
    _options.shuffle();

    // RÃ©soudre l'audio via YoutubeExplode
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(currentTrack.id)
          .timeout(const Duration(seconds: 10));
      String audioUrl = '';
      if (manifest.muxed.isNotEmpty) {
        try {
          audioUrl = manifest.muxed.sortByVideoQuality().first.url.toString();
        } catch(e) {
          audioUrl = manifest.muxed.first.url.toString();
        }
      } else if (manifest.audioOnly.isNotEmpty) {
        audioUrl = manifest.audioOnly.withHighestBitrate().url.toString();
      } else {
        throw Exception("Aucun flux audio disponible");
      }
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(audioUrl).timeout(const Duration(seconds: 8));
      _audioPlayer.play();
    } catch (e) {
      print('Erreur lecture audio quiz: $e');
      // Passer Ã  la question suivante en cas d'erreur audio
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        _skipToNextQuestion();
        return;
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

    Future.delayed(const Duration(seconds: 2), () {
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

  void _skipToNextQuestion() {
    _countdownTimer?.cancel();
    _audioPlayer.stop();
    setState(() {
      _currentQuestionIndex++;
    });
    if (_currentQuestionIndex < 10) {
      _prepareQuestion();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Quiz Musical", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 20),
            const Text("Préparation de la piste...", style: TextStyle(color: Colors.white54, fontSize: 16)).animate().shimmer(duration: 1.seconds, curve: Curves.easeInOut),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Question ${_currentQuestionIndex + 1}/10", style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text("Score: $_score", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),

          const SizedBox(height: 40),

          Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: const Icon(Icons.music_note, size: 80, color: Colors.white),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1.seconds, curve: Curves.easeInOut)
            .then()
            .scale(begin: const Offset(1.05, 1.05), end: const Offset(0.95, 0.95), duration: 1.seconds, curve: Curves.easeInOut),
          ),

          const SizedBox(height: 30),

          Center(
            child: Text(
              "00:${_timeLeft.toString().padLeft(2, '0')}",
              style: TextStyle(
                color: _timeLeft <= 5 ? Colors.red : Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            _askForArtist ? "Quel est le nom de cet artiste ?" : "Quel est le titre de ce morceau ?",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 40),

          Expanded(
            child: ListView.separated(
              itemCount: _options.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final option = _options[index];
                final isSelected = _selectedOption == option;
                final isCorrect = option == _correctAnswer;

                Color buttonColor = Colors.white.withOpacity(0.08);
                Color textColor = Colors.white;
                Color borderColor = Colors.white.withOpacity(0.2);

                if (_isAnswered) {
                  if (isCorrect) {
                    buttonColor = Colors.green.withOpacity(0.2);
                    textColor = Colors.green.shade300;
                    borderColor = Colors.green;
                  } else if (isSelected && !isCorrect) {
                    buttonColor = Colors.red.withOpacity(0.2);
                    textColor = Colors.red.shade300;
                    borderColor = Colors.red;
                  }
                } else if (isSelected) {
                  buttonColor = AppColors.primary.withOpacity(0.1);
                  borderColor = AppColors.primary;
                }

                return GestureDetector(
                  onTap: () => _handleAnswer(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    decoration: BoxDecoration(
                      color: buttonColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Text(
                      option,
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: 400 + (index * 100))).slideY(begin: 0.2),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 100, color: Colors.amber).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            const Text(
              "Fin de la partie !",
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 16),
            Text(
              "Ton score: $_score / 100",
              style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                _loadQuizData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("REJOUER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text("Retour à l'accueil", style: TextStyle(color: Colors.white54, fontSize: 16)),
            ).animate().fadeIn(delay: 900.ms),
          ],
        ),
      ),
    );
  }
}
