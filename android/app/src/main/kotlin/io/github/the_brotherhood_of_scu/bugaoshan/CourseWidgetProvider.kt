package io.github.the_brotherhood_of_scu.bugaoshan

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

abstract class CourseWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                Log.e("CourseWidget", "Failed to update widget $appWidgetId", e)
            }
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        try {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        } catch (e: Exception) {
            Log.e("CourseWidget", "Failed to update widget options $appWidgetId", e)
        }
    }

    companion object {
        private const val TAG = "CourseWidget"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val widgetData = HomeWidgetPlugin.getData(context)

            val headerTitle = widgetData.getString("widget_header_title", null) ?: "不高山上"
            val dateText = widgetData.getString("widget_date_text", null) ?: ""
            val weekText = widgetData.getString("widget_week_text", null) ?: ""
            val themeColor = widgetData.getInt("widget_theme_color", 0xFF2196F3.toInt())
            val noCoursesText = widgetData.getString("widget_no_courses_text", null) ?: "今天没有课程"
            val sectionPrefix = widgetData.getString("widget_section_prefix", null) ?: "第"
            val sectionSuffix = widgetData.getString("widget_section_suffix", null) ?: "节"
            val coursesJsonStr = widgetData.getString("widget_courses_json", null)

            val coursesArray = if (coursesJsonStr != null) {
                try { JSONArray(coursesJsonStr) } catch (e: Exception) { JSONArray() }
            } else {
                JSONArray()
            }

            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)

            val isSmall = minWidth < 180
            val isLarge = minWidth >= 300 && minHeight >= 250

            val views = when {
                isSmall -> buildSmallWidget(context, coursesArray, headerTitle, dateText, weekText, themeColor, noCoursesText)
                isLarge -> buildLargeWidget(context, appWidgetId, coursesArray, headerTitle, dateText, weekText, themeColor, noCoursesText, sectionPrefix, sectionSuffix)
                else -> buildMediumWidget(context, appWidgetId, coursesArray, headerTitle, dateText, weekText, themeColor, noCoursesText)
            }

            // Click to open app
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                val pendingIntent = PendingIntent.getActivity(
                    context, appWidgetId, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun buildSmallWidget(
            context: Context,
            coursesArray: JSONArray,
            headerTitle: String,
            dateText: String,
            weekText: String,
            themeColor: Int,
            noCoursesText: String
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_small)

            views.setTextViewText(R.id.widget_header_title, headerTitle)
            views.setTextViewText(R.id.widget_date_text, dateText)
            views.setTextViewText(R.id.widget_week_text, weekText)
            views.setInt(R.id.widget_header, "setBackgroundColor", themeColor)

            if (coursesArray.length() == 0) {
                views.setViewVisibility(R.id.widget_course_card, View.GONE)
                views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty_text, noCoursesText)
            } else {
                views.setViewVisibility(R.id.widget_course_card, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty_state, View.GONE)

                val course = coursesArray.getJSONObject(0)
                views.setTextViewText(R.id.widget_course_name, course.optString("name", ""))
                views.setTextViewText(
                    R.id.widget_course_time,
                    "${course.optString("startTime", "")}-${course.optString("endTime", "")}"
                )
                views.setTextViewText(R.id.widget_course_location, course.optString("location", ""))
                views.setInt(R.id.widget_course_strip, "setBackgroundColor", course.optInt("colorValue", 0xFF2196F3.toInt()))
            }

            return views
        }

        private fun buildMediumWidget(
            context: Context,
            appWidgetId: Int,
            coursesArray: JSONArray,
            headerTitle: String,
            dateText: String,
            weekText: String,
            themeColor: Int,
            noCoursesText: String
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_medium)

            views.setTextViewText(R.id.widget_header_title, headerTitle)
            views.setTextViewText(R.id.widget_date_text, dateText)
            views.setTextViewText(R.id.widget_week_text, weekText)
            views.setInt(R.id.widget_header, "setBackgroundColor", themeColor)

            if (coursesArray.length() == 0) {
                views.setViewVisibility(R.id.widget_listview, View.GONE)
                views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty_text, noCoursesText)
            } else {
                views.setViewVisibility(R.id.widget_listview, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty_state, View.GONE)

                val intent = Intent(context, CourseWidgetRemoteViewsService::class.java).apply {
                    putExtra("widget_style", 0)
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = android.net.Uri.parse("widget://medium/$appWidgetId")
                }
                views.setRemoteAdapter(R.id.widget_listview, intent)
            }

            return views
        }

        private fun buildLargeWidget(
            context: Context,
            appWidgetId: Int,
            coursesArray: JSONArray,
            headerTitle: String,
            dateText: String,
            weekText: String,
            themeColor: Int,
            noCoursesText: String,
            sectionPrefix: String,
            sectionSuffix: String
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_large)

            views.setTextViewText(R.id.widget_header_title, headerTitle)
            views.setTextViewText(R.id.widget_date_text, dateText)
            views.setTextViewText(R.id.widget_week_text, weekText)
            views.setInt(R.id.widget_header, "setBackgroundColor", themeColor)

            if (coursesArray.length() == 0) {
                views.setViewVisibility(R.id.widget_listview, View.GONE)
                views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty_text, noCoursesText)
            } else {
                views.setViewVisibility(R.id.widget_listview, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty_state, View.GONE)

                val intent = Intent(context, CourseWidgetRemoteViewsService::class.java).apply {
                    putExtra("widget_style", 1)
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = android.net.Uri.parse("widget://large/$appWidgetId")
                }
                views.setRemoteAdapter(R.id.widget_listview, intent)
            }

            return views
        }
    }
}
