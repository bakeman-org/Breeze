package com.zephyr.breeze

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/// 「最近下载」桌面小部件。
///
/// 数据由 Flutter 侧 HomeWidgetService 写入 SharedPreferences
/// `HomeWidgetPreferences`（home_widget 插件约定），本 Provider 只负责渲染：
/// 列表用 RemoteViewsService 提供，item 点击通过 fill-in intent 携带
/// `breeze://comic/{id}?from={source}&type=download`。
class BreezeRecentWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, buildRemoteViews(context))
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    private fun buildRemoteViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.breeze_recent_widget)
        val prefs =
            context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        val serviceIntent = Intent(context, BreezeRemoteViewsService::class.java).apply {
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_list, serviceIntent)
        views.setEmptyView(R.id.widget_list, R.id.widget_empty)

        // 列表 item 点击模板：数据 URI 由 Factory 的 fill-in intent 提供。
        views.setPendingIntentTemplate(
            R.id.widget_list,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )

        // 头部入口：标题 → 打开应用；插件/书架 → 对应页面。
        views.setOnClickPendingIntent(
            R.id.widget_header,
            entryIntent(context, "breeze://main"),
        )
        views.setOnClickPendingIntent(
            R.id.action_plugin,
            entryIntent(context, "breeze://plugin"),
        )
        views.setOnClickPendingIntent(
            R.id.action_bookshelf,
            entryIntent(context, "breeze://favorite"),
        )

        // 无已安装插件时隐藏「插件」入口。
        val pluginCount = prefs.getInt("plugin_count", 0)
        views.setViewVisibility(
            R.id.action_plugin,
            if (pluginCount > 0) View.VISIBLE else View.GONE,
        )
        return views
    }

    private fun entryIntent(context: Context, uri: String): PendingIntent {
        return HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse(uri),
        )
    }
}
