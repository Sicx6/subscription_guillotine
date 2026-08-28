package com.example.subscription_guillotine

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SubscriptionWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.subscription_widget).apply {
                setTextViewText(R.id.widget_total,
                    widgetData.getString("monthly_total", "MYR 0.00 / month"))
                setTextViewText(R.id.widget_count,
                    widgetData.getString("active_count", "0 active"))
                setTextViewText(R.id.widget_next,
                    widgetData.getString("next_charge", "No upcoming charges"))
                setOnClickPendingIntent(R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
