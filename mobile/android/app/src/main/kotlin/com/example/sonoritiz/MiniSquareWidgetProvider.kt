package com.example.sonoritiz

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.util.Log
import android.view.KeyEvent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class MiniSquareWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val coverPath = widgetData.getString("coverPath", null)
            val sampledCover = WidgetBitmapHelper.decodeSampledBitmap(coverPath, maxDim = 180)

            appWidgetIds.forEach { widgetId ->
                val views = RemoteViews(context.packageName, R.layout.widget_mini_square).apply {
                    val title = widgetData.getString("title", "Sonoritiz")
                    val artist = widgetData.getString("artist", "En écoute")
                    val isPlaying = widgetData.getBoolean("isPlaying", false)
                    val progress = widgetData.getInt("progress", 0)

                    setTextViewText(R.id.widget_title, title)
                    setTextViewText(R.id.widget_artist, artist)
                    setProgressBar(R.id.widget_progress, 1000, progress.coerceIn(0, 1000), false)

                    if (sampledCover != null) {
                        setImageViewBitmap(R.id.widget_cover, sampledCover)
                    } else {
                        setImageViewResource(R.id.widget_cover, R.mipmap.launcher_icon)
                    }

                    setImageViewResource(
                        R.id.btn_play_pause,
                        if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
                    )

                    try {
                        val playIntent = WidgetBitmapHelper.buildMediaPendingIntent(
                            context,
                            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                            requestCodeOffset = 3000
                        )
                        setOnClickPendingIntent(R.id.btn_play_pause, playIntent)
                    } catch (e: Throwable) {
                        Log.e("MiniSquareWidget", "Erreur media button: ${e.message}")
                    }

                    val launchIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("sonoritiz://player")
                    )
                    setOnClickPendingIntent(R.id.widget_cover, launchIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        } catch (e: Throwable) {
            Log.e("MiniSquareWidget", "Erreur onUpdate MiniSquareWidget: ${e.message}", e)
        }
    }
}
