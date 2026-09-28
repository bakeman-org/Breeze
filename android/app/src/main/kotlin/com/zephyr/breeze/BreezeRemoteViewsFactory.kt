package com.zephyr.breeze

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.io.File

/// 渲染最近下载列表，数据来自 SharedPreferences `HomeWidgetPreferences`
/// 中 Flutter 侧写入的 `recent_comics` JSON 数组。
class BreezeRemoteViewsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private data class WidgetComic(
        val title: String,
        val deepLink: String,
        val coverPath: String,
    )

    private val items = mutableListOf<WidgetComic>()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items.clear()
        val prefs =
            context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val json = prefs.getString("recent_comics", null) ?: return
        try {
            val array = JSONArray(json)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val comicId = obj.optString("comicId")
                if (comicId.isEmpty()) continue
                val source = Uri.encode(obj.optString("source"))
                items.add(
                    WidgetComic(
                        title = obj.optString("title"),
                        deepLink = "breeze://comic/$comicId?from=$source&type=download",
                        coverPath = obj.optString("coverPath"),
                    ),
                )
            }
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() = items.clear()

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val item = items[position]
        val views = RemoteViews(context.packageName, R.layout.breeze_recent_widget_item)
        views.setTextViewText(R.id.item_title, item.title)

        val file = if (item.coverPath.startsWith("/")) File(item.coverPath) else null
        val bitmap = file?.takeIf { it.exists() }
            ?.let { BitmapFactory.decodeFile(it.absolutePath) }
        if (bitmap != null) {
            views.setImageViewBitmap(R.id.item_cover, bitmap)
        } else {
            views.setImageViewResource(R.id.item_cover, R.drawable.widget_cover_placeholder)
        }

        views.setOnClickFillInIntent(
            R.id.item_root,
            Intent().apply { data = Uri.parse(item.deepLink) },
        )
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false
}
