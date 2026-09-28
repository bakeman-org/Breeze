package com.zephyr.breeze

import android.content.Intent
import android.widget.RemoteViewsService

/// 「最近下载」小部件的列表数据服务。
class BreezeRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return BreezeRemoteViewsFactory(applicationContext)
    }
}
