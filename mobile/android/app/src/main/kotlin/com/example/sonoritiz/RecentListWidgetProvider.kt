package com.example.sonoritiz

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class RecentListWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            appWidgetIds.forEach { widgetId ->
                val intent = Intent(context, RecentListWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }

                val views = RemoteViews(context.packageName, R.layout.widget_recent_list).apply {
                    setRemoteAdapter(R.id.widget_list_view, intent)
                    setEmptyView(R.id.widget_list_view, R.id.widget_empty_view)

                    val actionIntent = Intent(context, MainActivity::class.java).apply {
                        action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                        data = Uri.parse("sonoritiz://history")
                    }
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val pendingIntentTemplate = PendingIntent.getActivity(
                        context,
                        4000 + widgetId,
                        actionIntent,
                        flags
                    )

                    setPendingIntentTemplate(R.id.widget_list_view, pendingIntentTemplate)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list_view)
            }
        } catch (e: Throwable) {
            Log.e("RecentListWidget", "Erreur onUpdate: ${e.message}", e)
        }
    }
}
