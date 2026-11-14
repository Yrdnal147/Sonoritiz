import 'package:shared_preferences/shared_preferences.dart';
import '../../player/data/models/track_model.dart';
import '../../../core/notifications/notification_service.dart';
import '../../library/data/repositories/library_repository.dart';
import '../../home/data/repositories/catalog_repository.dart';

class NewReleaseNotifier {
  final LibraryRepository _libraryRepository;
  final CatalogRepository _catalogRepository;
  final NotificationService _notificationService = NotificationService();

  NewReleaseNotifier(this._libraryRepository, this._catalogRepository);

  Future<void> checkAndNotifyNewReleases(List<TrackModel> newReleases) async {
    if (newReleases.isEmpty) return;

    await _notificationService.initialize();

    final prefs = await SharedPreferences.getInstance();
    final notifiedIds = prefs.getStringList('notified_new_releases') ?? [];

    // 1. Get listened artists from history
    final history = await _libraryRepository.getHistory();
    final listenedArtists = history.map((e) => e.track?.artistName ?? '').where((name) => name.isNotEmpty).toSet();

    if (listenedArtists.isEmpty) return;

    // 2. Find matching new releases
    for (final track in newReleases) {
      if (listenedArtists.contains(track.artistName) && !notifiedIds.contains(track.id)) {
        
        // Fetch artist details to get a beautiful artist picture for the notification
        String artistImageUrl = '';
        try {
          final artistDetails = await _catalogRepository.getArtistDetailsDeezer(track.artistName);
          artistImageUrl = artistDetails['picture_xl'] ?? '';
        } catch (e) {
          // Fallback if network fails
        }
        
        await _notificationService.showNewReleaseNotification(track, artistImageUrl);

        // Mark as notified
        notifiedIds.add(track.id);
        
        // We only notify one at a time to avoid spamming multiple notifications at startup
        break; 
      }
    }

    await prefs.setStringList('notified_new_releases', notifiedIds);
  }
}

