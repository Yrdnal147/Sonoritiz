package com.example.sonoritiz

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.util.Log
import android.view.KeyEvent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class PlaylistWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val coverPath = widgetData.getString("coverPath", null)
            val mainBitmap = WidgetBitmapHelper.decodeSampledBitmap(coverPath, maxDim = 200)
            val histBitmaps = (0..4).map { idx ->
                WidgetBitmapHelper.decodeSampledBitmap(
                    widgetData.getString("hist_cover_$idx", null),
                    maxDim = 96
                )
            }

            appWidgetIds.forEach { widgetId ->
                val views = RemoteViews(context.packageName, R.layout.widget_playlist).apply {
                    val title = widgetData.getString("title", "Sonoritiz")
                    val artist = widgetData.getString("artist", "En attente de musique...")
                    val isPlaying = widgetData.getBoolean("isPlaying", false)
                    val isFavorite = widgetData.getBoolean("isFavorite", false)
                    val isRepeat = widgetData.getBoolean("isRepeat", false)
                    val progress = widgetData.getInt("progress", 0)
                    val positionText = widgetData.getString("positionText", "0:00")
                    val durationText = widgetData.getString("durationText", "0:00")

                    setTextViewText(R.id.widget_title, title)
                    setTextViewText(R.id.widget_artist, artist)
                    setTextViewText(R.id.widget_position, positionText)
                    setTextViewText(R.id.widget_duration, durationText)
                    setProgressBar(R.id.widget_progress, 1000, progress.coerceIn(0, 1000), false)

                    if (mainBitmap != null) {
                        setImageViewBitmap(R.id.widget_cover, mainBitmap)
                    } else {
                        setImageViewResource(R.id.widget_cover, R.mipmap.launcher_icon)
                    }

                    val historyIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("sonoritiz://history")
                    )

                    for (i in 0..4) {
                        val viewId = context.resources.getIdentifier("hist_cover_$i", "id", context.packageName)
                        if (viewId != 0) {
                            val bmp = histBitmaps[i]
                            if (bmp != null) {
                                setImageViewBitmap(viewId, bmp)
                            } else {
                                setImageViewResource(viewId, R.mipmap.launcher_icon)
                            }
                            setOnClickPendingIntent(viewId, historyIntent)
                        }
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
                            requestCodeOffset = 2000
                        )
                        setOnClickPendingIntent(R.id.btn_play_pause, playIntent)

                        val nextIntent = WidgetBitmapHelper.buildMediaPendingIntent(
                            context,
                            KeyEvent.KEYCODE_MEDIA_NEXT,
                            requestCodeOffset = 2000
                        )
                        setOnClickPendingIntent(R.id.btn_next, nextIntent)

                        val prevIntent = WidgetBitmapHelper.buildMediaPendingIntent(
                            context,
                            KeyEvent.KEYCODE_MEDIA_PREVIOUS,
                            requestCodeOffset = 2000
                        )
                        setOnClickPendingIntent(R.id.btn_prev, prevIntent)
                    } catch (e: Throwable) {
                        Log.e("PlaylistWidget", "Erreur media buttons: ${e.message}")
                    }

                    val favIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("sonoritiz://favorite"))
                    setOnClickPendingIntent(R.id.btn_favorite, favIntent)

                    val repeatIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("sonoritiz://repeat"))
                    setOnClickPendingIntent(R.id.btn_repeat, repeatIntent)

                    val lyricsIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("sonoritiz://lyrics")
                    )
                    setOnClickPendingIntent(R.id.btn_lyrics, lyricsIntent)

                    val playerIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("sonoritiz://player")
                    )
                    setOnClickPendingIntent(R.id.widget_cover, playerIntent)
                    setOnClickPendingIntent(R.id.widget_info_container, playerIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        } catch (e: Throwable) {
            Log.e("PlaylistWidget", "Erreur onUpdate PlaylistWidget: ${e.message}", e)
        }
    }
}
