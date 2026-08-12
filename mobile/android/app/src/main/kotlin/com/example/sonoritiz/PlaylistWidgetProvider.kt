package com.example.sonoritiz

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PlaylistWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_playlist).apply {
                
                val playlistName = widgetData.getString("playlist_name", "Vos Playlists")
                setTextViewText(R.id.widget_playlist_title, playlistName)

                // Open App on click, directing to library/playlists
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context, 
                    MainActivity::class.java,
                    Uri.parse("sonoritiz://playlists")
                )
                setOnClickPendingIntent(R.id.widget_playlist_container, launchIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
