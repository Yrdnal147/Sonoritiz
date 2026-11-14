package com.example.sonoritiz

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin

class RecentListWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return RecentListFactory(this.applicationContext)
    }
}

class RecentListFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private val items = mutableListOf<Map<String, String?>>()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items.clear()
        val widgetData = HomeWidgetPlugin.getData(context)
        for (i in 0..4) {
            val title = widgetData.getString("hist_title_$i", null)
            val artist = widgetData.getString("hist_artist_$i", null)
            val coverPath = widgetData.getString("hist_cover_$i", null)
            if (!title.isNullOrEmpty()) {
                items.add(mapOf("title" to title, "artist" to artist, "coverPath" to coverPath))
            }
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= items.size) {
            return RemoteViews(context.packageName, R.layout.widget_recent_item)
        }
        val item = items[position]
        val views = RemoteViews(context.packageName, R.layout.widget_recent_item)

        views.setTextViewText(R.id.item_title, item["title"] ?: "")
        views.setTextViewText(R.id.item_artist, item["artist"] ?: "")

        val sampledBitmap = WidgetBitmapHelper.decodeSampledBitmap(item["coverPath"], maxDim = 96)
        if (sampledBitmap != null) {
            views.setImageViewBitmap(R.id.item_cover, sampledBitmap)
        } else {
            views.setImageViewResource(R.id.item_cover, R.mipmap.launcher_icon)
        }

        val fillInIntent = Intent()
        views.setOnClickFillInIntent(R.id.recent_item_root, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
