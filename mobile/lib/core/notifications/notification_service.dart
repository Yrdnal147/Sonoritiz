import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/player/data/models/track_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_stat_logo_transparent');
        
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    // Request permissions for Android 13+
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final File file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    
    try {
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      await file.writeAsBytes(response.data);
      return filePath;
    } catch (e) {
      return '';
    }
  }

  Future<void> showNewReleaseNotification(TrackModel track, String artistImageUrl) async {
    // Try to download images for a rich notification
    String largeIconPath = '';
    String bigPicturePath = '';
    
    if (artistImageUrl.isNotEmpty) {
      largeIconPath = await _downloadAndSaveFile(artistImageUrl, 'artist_${track.artistName}.jpg');
    }
    if (track.coverUrl.isNotEmpty) {
      bigPicturePath = await _downloadAndSaveFile(track.coverUrl, 'track_${track.id}.jpg');
    }

    BigPictureStyleInformation? bigPictureStyleInformation;
    if (bigPicturePath.isNotEmpty) {
      bigPictureStyleInformation = BigPictureStyleInformation(
        FilePathAndroidBitmap(bigPicturePath),
        largeIcon: largeIconPath.isNotEmpty ? FilePathAndroidBitmap(largeIconPath) : null,
        contentTitle: "Nouveau son de ${track.artistName} !",
        summaryText: "Venez découvrir le nouveau son ${track.title} de l'un de vos artistes ${track.artistName} sur Sonoritiz.",
        htmlFormatContentTitle: true,
        htmlFormatSummaryText: true,
      );
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'new_releases_channel',
      'Nouvelles Sorties',
      channelDescription: 'Notifications pour les nouveaux sons de vos artistes préférés',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Nouveau son disponible !',
      styleInformation: bigPictureStyleInformation,
      largeIcon: largeIconPath.isNotEmpty && bigPictureStyleInformation == null 
          ? FilePathAndroidBitmap(largeIconPath) 
          : null,
    );
    
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      track.id.hashCode.abs(),
      "Nouveau son de ${track.artistName} !",
      "Venez découvrir le nouveau son ${track.title} de l'un de vos artistes ${track.artistName} sur Sonoritiz.",
      platformChannelSpecifics,
    );
  }
}
