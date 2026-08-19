package com.example.sonoritiz

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class MiniSquareWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_mini_square).apply {
                
                val title = widgetData.getString("title", "Sonoritiz")
                val coverPath = widgetData.getString("coverPath", null)

                setTextViewText(R.id.widget_title, title)

                if (coverPath != null) {
                    setImageViewUri(R.id.widget_cover, Uri.parse(coverPath))
                } else {
                    setImageViewResource(R.id.widget_cover, R.mipmap.launcher_icon)
                }

                // Interactions (Play/Pause)
                val playIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("sonoritiz://playpause"))
                setOnClickPendingIntent(R.id.btn_play_pause, playIntent)

                // Open App on click
                val launchIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_cover, launchIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
