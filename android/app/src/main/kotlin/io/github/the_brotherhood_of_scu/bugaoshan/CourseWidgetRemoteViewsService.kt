package io.github.the_brotherhood_of_scu.bugaoshan

import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class CourseWidgetRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val style = intent.getIntExtra("widget_style", 0)
        return CourseRemoteViewsFactory(applicationContext, style)
    }
}

class CourseRemoteViewsFactory(
    private val context: Context,
    private val style: Int // 0 = medium, 1 = large
) : RemoteViewsService.RemoteViewsFactory {

    private var courses: JSONArray = JSONArray()
    private var sectionPrefix: String = "第"
    private var sectionSuffix: String = "节"

    override fun onCreate() {}

    override fun onDataSetChanged() {
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val coursesJsonStr = widgetData.getString("widget_courses_json", null)
            courses = if (coursesJsonStr != null) {
                try { JSONArray(coursesJsonStr) } catch (e: Exception) { JSONArray() }
            } else {
                JSONArray()
            }
            sectionPrefix = widgetData.getString("widget_section_prefix", null) ?: "第"
            sectionSuffix = widgetData.getString("widget_section_suffix", null) ?: "节"
        } catch (e: Exception) {
            Log.e("CourseWidget", "Failed to load widget data", e)
            courses = JSONArray()
        }
    }

    override fun onDestroy() {
        courses = JSONArray()
    }

    override fun getCount(): Int = courses.length()

    override fun getViewAt(position: Int): RemoteViews {
        val layoutId = if (style == 1) R.layout.widget_course_row_large else R.layout.widget_course_row_medium
        val views = RemoteViews(context.packageName, layoutId)

        try {
            if (position < 0 || position >= courses.length()) return views

            val course = courses.getJSONObject(position)
            views.setTextViewText(R.id.course_name, course.optString("name", ""))
            views.setInt(R.id.course_strip, "setBackgroundColor", course.optInt("colorValue", 0xFF2196F3.toInt()))

            if (style == 1) {
                val startSection = course.optInt("startSection", 0)
                val endSection = course.optInt("endSection", 0)
                val sectionText = if (startSection == endSection) {
                    "$sectionPrefix$startSection$sectionSuffix"
                } else {
                    "$sectionPrefix$startSection-$endSection$sectionSuffix"
                }
                views.setTextViewText(
                    R.id.course_time_section,
                    "${course.optString("startTime", "")}-${course.optString("endTime", "")}  $sectionText"
                )
                views.setTextViewText(R.id.course_location, course.optString("location", ""))
            } else {
                views.setTextViewText(
                    R.id.course_time,
                    "${course.optString("startTime", "")}-${course.optString("endTime", "")}"
                )
                views.setTextViewText(R.id.course_location, course.optString("location", ""))
            }
        } catch (e: Exception) {
            Log.e("CourseWidget", "Failed to build view at $position", e)
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false
}
