package com.example.sonoritiz

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NowPlayingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_now_playing).apply {
                
                val title = widgetData.getString("title", "Sonoritiz")
                val artist = widgetData.getString("artist", "En attente de musique...")
                val coverUrl = widgetData.getString("coverUrl", null)

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_artist, artist)

                // Interactions (Play/Pause, Next, Prev)
                val playIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("sonoritiz://playpause"))
                setOnClickPendingIntent(R.id.btn_play_pause, playIntent)

                val nextIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("sonoritiz://next"))
                setOnClickPendingIntent(R.id.btn_next, nextIntent)

                val prevIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("sonoritiz://prev"))
                setOnClickPendingIntent(R.id.btn_prev, prevIntent)

                // Open App on click
                val launchIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_cover, launchIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
