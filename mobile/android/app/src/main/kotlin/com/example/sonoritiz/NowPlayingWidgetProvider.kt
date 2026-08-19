package com.example.sonoritiz

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import android.appwidget.AppWidgetProvider
import es.antonborri.home_widget.HomeWidgetPlugin

class NowPlayingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_now_playing).apply {
                
                val title = widgetData.getString("title", "Sonoritiz")
                val artist = widgetData.getString("artist", "En attente de musique...")
                val coverPath = widgetData.getString("coverPath", null)

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_artist, artist)

                if (coverPath != null) {
                    setImageViewUri(R.id.widget_cover, Uri.parse(coverPath))
                } else {
                    setImageViewResource(R.id.widget_cover, R.mipmap.launcher_icon)
                }

                // Interactions (Play/Pause, Next, Prev, Favorite)
                val playIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("sonoritiz://playpause"))
                setOnClickPendingIntent(R.id.btn_play_pause, playIntent)

                val nextIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("sonoritiz://next"))
                setOnClickPendingIntent(R.id.btn_next, nextIntent)

                val prevIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("sonoritiz://prev"))
                setOnClickPendingIntent(R.id.btn_prev, prevIntent)

                val favIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("sonoritiz://favorite"))
                setOnClickPendingIntent(R.id.btn_favorite, favIntent)

                val isFavorite = widgetData.getBoolean("isFavorite", false)
                if (isFavorite) {
                    setInt(R.id.btn_favorite, "setColorFilter", android.graphics.Color.parseColor("#FF5E5B"))
                } else {
                    setInt(R.id.btn_favorite, "setColorFilter", android.graphics.Color.WHITE)
                }

                // Open App on click
                val launchIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_cover, launchIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
