package io.github.the_brotherhood_of_scu.bugaoshan

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Calendar

// ── Data loaded from SQLite for the widget ──────────────────────────

data class WidgetCourseData(
    val courses: JSONArray,
    val dateText: String,
    val weekText: String,
    val headerTitle: String,
    val emptyText: String,
    val sectionPrefix: String,
    val sectionSuffix: String,
    val themeColor: Int,
)

// ── SQLite data loader ──────────────────────────────────────────────

object WidgetDataLoader {
    private const val TAG = "CourseWidget"

    fun load(context: Context): WidgetCourseData? {
        val dbFile = File(context.filesDir, "bugaoshan.db")
        if (!dbFile.exists()) {
            Log.w(TAG, "Database not found at ${dbFile.path}")
            return null
        }

        var db: SQLiteDatabase? = null
        try {
            db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)

            // 1. Get current schedule ID
            val currentScheduleId = queryMetadata(db, "currentScheduleId") ?: "default"

            // 2. Get schedule config
            val configJson = queryScheduleConfig(db, currentScheduleId) ?: return null
            val config = JSONObject(configJson)

            val semesterStartDate = config.optString("semesterStartDate", "")
            val totalWeeks = config.optInt("totalWeeks", 20)
            val timeSlots = config.optJSONArray("timeSlots")

            // 3. Compute current week
            val currentWeek = computeCurrentWeek(semesterStartDate, totalWeeks)

            // 4. Get today's day of week (1=Mon ... 7=Sun)
            val cal = Calendar.getInstance()
            val dayOfWeek = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1 // Convert to 1=Mon

            // 5. Query today's courses
            val courses = queryCourses(db, currentScheduleId, dayOfWeek, currentWeek)

            // 6. Resolve time strings
            for (i in 0 until courses.length()) {
                val c = courses.getJSONObject(i)
                val ss = c.optInt("startSection", 0)
                val es = c.optInt("endSection", 0)
                c.put("startTime", formatTime(timeSlots, ss))
                c.put("endTime", formatTime(timeSlots, es))
            }

            // 7. Build display strings
            val now = Calendar.getInstance()
            val month = now.get(Calendar.MONTH) + 1
            val day = now.get(Calendar.DAY_OF_MONTH)
            val dayNames = arrayOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")
            val dayName = dayNames[dayOfWeek - 1]
            val dateText = "$month/$day $dayName"
            val weekText = "第${currentWeek}周"

            // 8. Get theme color from SharedPreferences (still written by Flutter)
            val prefs = HomeWidgetPlugin.getData(context)
            val themeColor = prefs.getInt("widget_theme_color", 0xFF2196F3.toInt())

            Log.d(TAG, "Loaded ${courses.length()} courses for week $currentWeek, day $dayOfWeek")

            return WidgetCourseData(
                courses = courses,
                dateText = dateText,
                weekText = weekText,
                headerTitle = "不高山上",
                emptyText = "今天没有课程",
                sectionPrefix = "第",
                sectionSuffix = "节",
                themeColor = themeColor,
            )
        } catch (e: Exception) {
            Log.e(TAG, "WidgetDataLoader.load failed", e)
            return null
        } finally {
            db?.close()
        }
    }

    private fun queryMetadata(db: SQLiteDatabase, key: String): String? {
        db.rawQuery("SELECT value FROM metadata WHERE key = ?", arrayOf(key)).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }

    private fun queryScheduleConfig(db: SQLiteDatabase, scheduleId: String): String? {
        db.rawQuery(
            "SELECT config_json FROM schedules WHERE id = ?",
            arrayOf(scheduleId)
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }

    private fun queryCourses(
        db: SQLiteDatabase,
        scheduleId: String,
        dayOfWeek: Int,
        currentWeek: Int
    ): JSONArray {
        val result = JSONArray()
        db.rawQuery(
            """SELECT name, teacher, location, start_week, end_week,
                      start_section, end_section, color_value, week_type
               FROM courses
               WHERE schedule_id = ? AND day_of_week = ?""",
            arrayOf(scheduleId, dayOfWeek.toString())
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val startWeek = cursor.getInt(3)
                val endWeek = cursor.getInt(4)
                val weekType = cursor.getInt(8) // 0=every, 1=odd, 2=even

                if (!isCourseActive(currentWeek, startWeek, endWeek, weekType)) continue

                val obj = JSONObject()
                obj.put("name", cursor.getString(0) ?: "")
                obj.put("teacher", cursor.getString(1) ?: "")
                obj.put("location", cursor.getString(2) ?: "")
                obj.put("startSection", cursor.getInt(5))
                obj.put("endSection", cursor.getInt(6))
                obj.put("colorValue", cursor.getInt(7))
                result.put(obj)
            }
        }
        // Sort by startSection
        val sorted = (0 until result.length())
            .map { result.getJSONObject(it) }
            .sortedBy { it.optInt("startSection", 0) }
        return JSONArray().apply { sorted.forEach { put(it) } }
    }

    private fun isCourseActive(week: Int, startWeek: Int, endWeek: Int, weekType: Int): Boolean {
        if (week < startWeek || week > endWeek) return false
        if (weekType == 1 && week % 2 == 0) return false // odd week
        if (weekType == 2 && week % 2 == 1) return false // even week
        return true
    }

    private fun computeCurrentWeek(semesterStartDate: String, totalWeeks: Int): Int {
        if (semesterStartDate.isEmpty()) return 1
        val parts = semesterStartDate.split("-")
        if (parts.size != 3) return 1
        val startCal = Calendar.getInstance().apply {
            set(parts[0].toInt(), parts[1].toInt() - 1, parts[2].toInt(), 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val now = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (now.before(startCal)) return 1
        val days = ((now.timeInMillis - startCal.timeInMillis) / (1000 * 60 * 60 * 24)).toInt()
        val week = days / 7 + 1
        return week.coerceIn(1, totalWeeks)
    }

    private fun formatTime(timeSlots: JSONArray?, section: Int): String {
        if (timeSlots == null || section < 1 || section > timeSlots.length()) return "--:--"
        val slot = timeSlots.getJSONObject(section - 1)
        val start = slot.optJSONObject("startTime") ?: return "--:--"
        val h = start.optInt("hour", 0).toString().padStart(2, '0')
        val m = start.optInt("minute", 0).toString().padStart(2, '0')
        return "$h:$m"
    }
}

// ── Widget Provider ─────────────────────────────────────────────────

abstract class CourseWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate: ${appWidgetIds.size} widgets")
        for (id in appWidgetIds) {
            try { updateAppWidget(context, appWidgetManager, id) }
            catch (e: Exception) { Log.e(TAG, "updateAppWidget failed", e) }
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        try { updateAppWidget(context, appWidgetManager, appWidgetId) }
        catch (e: Exception) { Log.e(TAG, "optionsChanged failed", e) }
    }

    companion object {
        private const val TAG = "CourseWidget"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val data = WidgetDataLoader.load(context)
            val title = data?.headerTitle ?: "不高山上"
            val date = data?.dateText ?: ""
            val week = data?.weekText ?: ""
            val color = data?.themeColor ?: 0xFF2196F3.toInt()
            val empty = data?.emptyText ?: "今天没有课程"
            val arr = data?.courses ?: JSONArray()
            val sPre = data?.sectionPrefix ?: "第"
            val sSuf = data?.sectionSuffix ?: "节"

            Log.d(TAG, "courses=${arr.length()} title=$title date=$date")

            val opts = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)

            val isSmall = w < 180
            val isLarge = w >= 300 && h >= 250
            Log.d(TAG, "size=${w}x$h type: small=$isSmall large=$isLarge")

            val views: RemoteViews
            if (isSmall) {
                views = buildSmall(context, arr, title, date, week, empty)
            } else if (isLarge) {
                views = buildList(context, appWidgetId, arr, title, date, week, empty, R.layout.widget_large, 1)
            } else {
                views = buildList(context, appWidgetId, arr, title, date, week, empty, R.layout.widget_medium, 0)
            }

            // click -> open app
            try {
                val li = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (li != null) {
                    li.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    val pi = PendingIntent.getActivity(
                        context, appWidgetId, li,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_container, pi)
                }
            } catch (e: Exception) {
                Log.e(TAG, "click intent failed", e)
            }

            if (!isSmall) {
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_listview)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "done $appWidgetId")
        }

        private fun buildSmall(
            ctx: Context, arr: JSONArray,
            title: String, date: String, week: String, empty: String
        ): RemoteViews {
            val v = RemoteViews(ctx.packageName, R.layout.widget_small)
            v.setTextViewText(R.id.widget_header_title, title)
            v.setTextViewText(R.id.widget_date_text, date)
            v.setTextViewText(R.id.widget_week_text, week)
            if (arr.length() == 0) {
                v.setViewVisibility(R.id.widget_course_card, View.GONE)
                v.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                v.setTextViewText(R.id.widget_empty_text, empty)
            } else {
                v.setViewVisibility(R.id.widget_course_card, View.VISIBLE)
                v.setViewVisibility(R.id.widget_empty_state, View.GONE)
                val c = arr.getJSONObject(0)
                v.setTextViewText(R.id.widget_course_name, c.optString("name", ""))
                v.setTextViewText(R.id.widget_course_time,
                    "${c.optString("startTime","")}-${c.optString("endTime","")}")
                v.setTextViewText(R.id.widget_course_location, c.optString("location", ""))
            }
            return v
        }

        private fun buildList(
            ctx: Context, widgetId: Int, arr: JSONArray,
            title: String, date: String, week: String, empty: String,
            layoutRes: Int, style: Int
        ): RemoteViews {
            val v = RemoteViews(ctx.packageName, layoutRes)
            v.setTextViewText(R.id.widget_header_title, title)
            v.setTextViewText(R.id.widget_date_text, date)
            v.setTextViewText(R.id.widget_week_text, week)
            if (arr.length() == 0) {
                v.setViewVisibility(R.id.widget_listview, View.GONE)
                v.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                v.setTextViewText(R.id.widget_empty_text, empty)
            } else {
                v.setViewVisibility(R.id.widget_listview, View.VISIBLE)
                v.setViewVisibility(R.id.widget_empty_state, View.GONE)
                val intent = Intent(ctx, CourseWidgetRemoteViewsService::class.java)
                intent.putExtra("widget_style", style)
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                intent.data = android.net.Uri.parse("widget://$style/$widgetId")
                v.setRemoteAdapter(R.id.widget_listview, intent)
            }
            return v
        }
    }
}

class CourseWidgetProviderSmall  : CourseWidgetProvider()
class CourseWidgetProviderMedium : CourseWidgetProvider()
class CourseWidgetProviderLarge  : CourseWidgetProvider()

// ── RemoteViewsService ──────────────────────────────────────────────

class CourseWidgetRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CourseRemoteViewsFactory(applicationContext, intent.getIntExtra("widget_style", 0))
    }
}

class CourseRemoteViewsFactory(
    private val context: Context,
    private val style: Int
) : RemoteViewsService.RemoteViewsFactory {

    private var courses = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        try {
            val data = WidgetDataLoader.load(context)
            courses = data?.courses ?: JSONArray()
            Log.d("CourseWidget", "Factory: loaded ${courses.length()} courses")
        } catch (e: Exception) {
            Log.e("CourseWidget", "onDataSetChanged failed", e)
            courses = JSONArray()
        }
    }

    override fun onDestroy() { courses = JSONArray() }
    override fun getCount() = courses.length()

    override fun getViewAt(pos: Int): RemoteViews {
        val layout = if (style == 1) R.layout.widget_course_row_large else R.layout.widget_course_row_medium
        val v = RemoteViews(context.packageName, layout)
        try {
            if (pos < 0 || pos >= courses.length()) return v
            val c = courses.getJSONObject(pos)
            v.setTextViewText(R.id.course_name, c.optString("name", ""))
            v.setTextViewText(R.id.course_time,
                "${c.optString("startTime","")}-${c.optString("endTime","")}")
            v.setTextViewText(R.id.course_location, c.optString("location", ""))
            if (style == 1) {
                val ss = c.optInt("startSection", 0)
                val es = c.optInt("endSection", 0)
                val sec = if (ss == es) "第${ss}节" else "第${ss}-${es}节"
                v.setTextViewText(R.id.course_time_section,
                    "${c.optString("startTime","")}-${c.optString("endTime","")}  $sec")
            }
        } catch (e: Exception) {
            Log.e("CourseWidget", "getViewAt($pos) failed", e)
        }
        return v
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount() = 1
    override fun getItemId(pos: Int) = pos.toLong()
    override fun hasStableIds() = false
}
