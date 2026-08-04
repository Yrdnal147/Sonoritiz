import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/player/data/models/track_model.dart';

class ShareUtils {
  static Future<void> shareTrack(TrackModel track) async {
    final text = "Écoute '\${track.title}' de \${track.artistName} sur Sonoritiz !";
    
    if (track.coverUrl.isEmpty) {
      // Pas de pochette, partage du texte simple
      await Share.share(text);
      return;
    }

    try {
      // Télécharger temporairement la pochette
      final tempDir = await getTemporaryDirectory();
      
      // Nettoyer l'extension au cas où l'URL aurait des paramètres (ex: image.jpg?v=1)
      final uri = Uri.parse(track.coverUrl);
      String ext = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.split('.').last : 'jpg';
      if (!['jpg', 'jpeg', 'png'].contains(ext.toLowerCase())) {
        ext = 'jpg';
      }

      final localPath = '\${tempDir.path}/share_\${track.id}.$ext';
      final file = File(localPath);

      // Ne pas retélécharger si déjà présent dans le cache temp
      if (!await file.exists()) {
        final dio = Dio();
        await dio.download(track.coverUrl, localPath);
      }

      // Partager avec l'image
      final xFile = XFile(localPath);
      await Share.shareXFiles([xFile], text: text);

    } catch (e) {
      // En cas d'erreur de téléchargement, fallback sur le partage de texte
      await Share.share(text);
    }
  }
}
