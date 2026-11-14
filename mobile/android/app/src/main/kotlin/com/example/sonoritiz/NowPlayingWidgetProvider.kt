package com.example.sonoritiz

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class NowPlayingWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val coverPath = widgetData.getString("coverPath", null)
            val sampledCover = WidgetBitmapHelper.decodeSampledBitmap(coverPath, maxDim = 220)

            val artistAvatarPath = widgetData.getString("artistAvatarPath", null)
            val sampledArtist = WidgetBitmapHelper.decodeSampledBitmap(artistAvatarPath, maxDim = 120)
            val circularArtist = WidgetBitmapHelper.createCircularBitmap(sampledArtist)

            appWidgetIds.forEach { widgetId ->
                val views = RemoteViews(context.packageName, R.layout.widget_now_playing).apply {
                    val title = widgetData.getString("title", "Sonoritiz")
                    val artist = widgetData.getString("artist", "En attente de musique...")
                    val isPlaying = widgetData.getBoolean("isPlaying", false)
                    val isFavorite = widgetData.getBoolean("isFavorite", false)
                    val isSuperliked = widgetData.getBoolean("isSuperliked", false)
                    val isRepeat = widgetData.getBoolean("isRepeat", false)
                    val progress = widgetData.getInt("progress", 0)
                    val positionText = widgetData.getString("positionText", "0:00")
                    val durationText = widgetData.getString("durationText", "0:00")

                    setTextViewText(R.id.widget_title, title)
                    setTextViewText(R.id.widget_artist, artist)
                    setTextViewText(R.id.widget_position, positionText)
                    setTextViewText(R.id.widget_duration, durationText)

                    // Gestion de la jauge : dorée si Superlike, blanche par défaut
                    val clampedProgress = progress.coerceIn(0, 1000)
                    if (isSuperliked) {
                        setViewVisibility(R.id.widget_progress, View.GONE)
                        setViewVisibility(R.id.widget_progress_superlike, View.VISIBLE)
                        setProgressBar(R.id.widget_progress_superlike, 1000, clampedProgress, false)
                    } else {
                        setViewVisibility(R.id.widget_progress_superlike, View.GONE)
                        setViewVisibility(R.id.widget_progress, View.VISIBLE)
                        setProgressBar(R.id.widget_progress, 1000, clampedProgress, false)
                    }

                    if (sampledCover != null) {
                        setImageViewBitmap(R.id.widget_cover, sampledCover)
                    } else {
                        setImageViewResource(R.id.widget_cover, R.mipmap.launcher_icon)
                    }

                    // Avatar circulaire de l'artiste principal (remplace le bouton favori)
                    if (circularArtist != null) {
                        setImageViewBitmap(R.id.btn_artist_avatar, circularArtist)
                    } else if (sampledCover != null) {
                        val coverCircle = WidgetBitmapHelper.createCircularBitmap(sampledCover)
                        setImageViewBitmap(R.id.btn_artist_avatar, coverCircle ?: sampledCover)
                    } else {
                        setImageViewResource(R.id.btn_artist_avatar, R.mipmap.launcher_icon)
                    }

                    setImageViewResource(
                        R.id.btn_play_pause,
                        if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
                    )

                    setImageViewResource(
                        R.id.btn_favorite,
                        if (isFavorite) R.drawable.ic_widget_fav_active else R.drawable.ic_widget_fav_inactive
                    )

                    setImageViewResource(
                        R.id.btn_repeat,
                        if (isRepeat) R.drawable.ic_widget_repeat_active else R.drawable.ic_widget_repeat_inactive
                    )

                    try {
                        val playIntent = WidgetBitmapHelper.buildMediaPendingIntent(
                            context,
                            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                            requestCodeOffset = 1000
                        )
                        setOnClickPendingIntent(R.id.btn_play_pause, playIntent)

                        val nextIntent = WidgetBitmapHelper.buildMediaPendingIntent(
                            context,
                            KeyEvent.KEYCODE_MEDIA_NEXT,
                            requestCodeOffset = 1000
                        )
                        setOnClickPendingIntent(R.id.btn_next, nextIntent)

                        val prevIntent = WidgetBitmapHelper.buildMediaPendingIntent(
                            context,
                            KeyEvent.KEYCODE_MEDIA_PREVIOUS,
                            requestCodeOffset = 1000
                        )
                        setOnClickPendingIntent(R.id.btn_prev, prevIntent)
                    } catch (e: Throwable) {
                        Log.e("NowPlayingWidget", "Erreur configuration media buttons: ${e.message}")
                    }

                    // Tap sur l'avatar de l'artiste -> ouvre le profil de l'artiste
                    val artistIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("sonoritiz://artist")
                    )
                    setOnClickPendingIntent(R.id.btn_artist_avatar, artistIntent)

                    val favIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("sonoritiz://favorite")
                    )
                    setOnClickPendingIntent(R.id.btn_favorite, favIntent)

                    val repeatIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("sonoritiz://repeat")
                    )
                    setOnClickPendingIntent(R.id.btn_repeat, repeatIntent)

                    val playerIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("sonoritiz://player")
                    )
                    setOnClickPendingIntent(R.id.widget_cover, playerIntent)
                    setOnClickPendingIntent(R.id.widget_info_container, playerIntent)
                    setOnClickPendingIntent(R.id.btn_queue, playerIntent)

                    val lyricsIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("sonoritiz://lyrics")
                    )
                    setOnClickPendingIntent(R.id.btn_lyrics, lyricsIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        } catch (e: Throwable) {
            Log.e("NowPlayingWidget", "Erreur onUpdate NowPlayingWidget: ${e.message}", e)
        }
    }
}
