package io.github.the_brotherhood_of_scu.bugaoshan

import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
        val dbFile = findDatabase(context)
        if (dbFile == null) {
            Log.e(TAG, "Database not found!")
            return null
        }

        var db: SQLiteDatabase? = null
        try {
            db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)

            val currentScheduleId = queryMetadata(db, "currentScheduleId") ?: "default"

            val configJson = queryScheduleConfig(db, currentScheduleId)
            if (configJson == null) {
                Log.e(TAG, "No schedule config found for id=$currentScheduleId")
                return null
            }
            val config = JSONObject(configJson)

            val semesterStartDate = config.optString("semesterStartDate", "")
            val totalWeeks = config.optInt("totalWeeks", 20)
            val timeSlots = config.optJSONArray("timeSlots")

            val currentWeek = computeCurrentWeek(semesterStartDate, totalWeeks)

            val cal = Calendar.getInstance()
            val dayOfWeek = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1

            var courses = queryCourses(db, currentScheduleId, dayOfWeek, currentWeek)
            if (courses.length() == 0 && currentScheduleId != "default") {
                courses = queryCourses(db, "default", dayOfWeek, currentWeek)
            }

            val now = Calendar.getInstance()
            val currentHour = now.get(Calendar.HOUR_OF_DAY)
            val currentMinute = now.get(Calendar.MINUTE)
            val currentTimeMinutes = currentHour * 60 + currentMinute

            val filteredCourses = JSONArray()
            for (i in 0 until courses.length()) {
                val c = courses.getJSONObject(i)
                val ss = c.optInt("startSection", 0)
                val es = c.optInt("endSection", 0)
                c.put("startTime", formatTime(timeSlots, ss))
                c.put("endTime", formatTime(timeSlots, es))

                // Filter out courses that have already ended
                val endSlot = getSlotEndTime(timeSlots, es)
                if (endSlot != null) {
                    val endMinutes = endSlot.first * 60 + endSlot.second
                    if (currentTimeMinutes >= endMinutes) continue
                }

                // Mark course status: inProgress or upcoming
                val startSlot = getSlotStartTime(timeSlots, ss)
                if (startSlot != null && endSlot != null) {
                    val startMinutes = startSlot.first * 60 + startSlot.second
                    val endMinutes = endSlot.first * 60 + endSlot.second
                    c.put("status", if (currentTimeMinutes in startMinutes until endMinutes) "inProgress" else "upcoming")
                } else {
                    c.put("status", "upcoming")
                }

                filteredCourses.put(c)
            }
            courses = filteredCourses
            val month = now.get(Calendar.MONTH) + 1
            val day = now.get(Calendar.DAY_OF_MONTH)
            val dayNames = arrayOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")
            val dayName = dayNames[dayOfWeek - 1]
            val dateText = "$month/$day $dayName"
            val weekText = "第${currentWeek}周"

            val themeColor = 0xFF2196F3.toInt()

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

    private fun findDatabase(context: Context): File? {
        val candidates = listOf(
            File(context.filesDir, "bugaoshan.db"),
            File(context.dataDir, "databases/bugaoshan.db"),
            File(context.dataDir, "files/bugaoshan.db"),
            File("/data/data/${context.packageName}/files/bugaoshan.db"),
            File("/data/data/${context.packageName}/databases/bugaoshan.db"),
        )
        for (f in candidates) {
            if (f.exists()) return f
        }
        return null
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
            if (cursor.moveToFirst()) return cursor.getString(0)
        }
        if (scheduleId != "default") {
            db.rawQuery(
                "SELECT config_json FROM schedules WHERE id = 'default'",
                null
            ).use { cursor ->
                if (cursor.moveToFirst()) return cursor.getString(0)
            }
        }
        db.rawQuery("SELECT config_json FROM schedules LIMIT 1", null).use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0)
        }
        return null
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
                val name = cursor.getString(0) ?: ""
                val startWeek = cursor.getInt(3)
                val endWeek = cursor.getInt(4)
                val weekType = cursor.getInt(8)

                if (!isCourseActive(currentWeek, startWeek, endWeek, weekType)) continue

                val obj = JSONObject()
                obj.put("name", name)
                obj.put("teacher", cursor.getString(1) ?: "")
                obj.put("location", cursor.getString(2) ?: "")
                obj.put("startSection", cursor.getInt(5))
                obj.put("endSection", cursor.getInt(6))
                obj.put("colorValue", cursor.getInt(7))
                result.put(obj)
            }
        }
        val sorted = (0 until result.length())
            .map { result.getJSONObject(it) }
            .sortedBy { it.optInt("startSection", 0) }
        return JSONArray().apply { sorted.forEach { put(it) } }
    }

    private fun isCourseActive(week: Int, startWeek: Int, endWeek: Int, weekType: Int): Boolean {
        if (week < startWeek || week > endWeek) return false
        if (weekType == 1 && week % 2 == 0) return false
        if (weekType == 2 && week % 2 == 1) return false
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

    private fun getSlotStartTime(timeSlots: JSONArray?, section: Int): Pair<Int, Int>? {
        if (timeSlots == null || section < 1 || section > timeSlots.length()) return null
        val slot = timeSlots.getJSONObject(section - 1)
        val start = slot.optJSONObject("startTime") ?: return null
        return Pair(start.optInt("hour", 0), start.optInt("minute", 0))
    }

    private fun getSlotEndTime(timeSlots: JSONArray?, section: Int): Pair<Int, Int>? {
        if (timeSlots == null || section < 1 || section > timeSlots.length()) return null
        val slot = timeSlots.getJSONObject(section - 1)
        val end = slot.optJSONObject("endTime") ?: return null
        return Pair(end.optInt("hour", 0), end.optInt("minute", 0))
    }
}

// ── Glance Widget ───────────────────────────────────────────────────

class CourseGlanceWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = WidgetDataLoader.load(context)
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        provideContent {
            GlanceTheme {
                val size = LocalSize.current
                val widthDp = size.width.value.toInt()
                val heightDp = size.height.value.toInt()
                val isSmall = widthDp < 180
                val isLarge = widthDp >= 300 && heightDp >= 250

                when {
                    isSmall -> SmallWidget(data, launchIntent)
                    isLarge -> LargeWidget(data, launchIntent)
                    else -> MediumWidget(data, launchIntent)
                }
            }
        }
    }

    @Composable
    private fun SmallWidget(data: WidgetCourseData?, launchIntent: Intent) {
        val courses = data?.courses ?: JSONArray()
        val title = data?.headerTitle ?: "不高山上"
        val date = data?.dateText ?: ""
        val week = data?.weekText ?: ""
        val emptyText = data?.emptyText ?: "今天没有课程"

        // Pick courses to show: current + next if in class, otherwise next 2 upcoming
        val displayCourses = mutableListOf<JSONObject>()
        var foundInProgress = false
        for (i in 0 until courses.length()) {
            val c = courses.getJSONObject(i)
            val status = c.optString("status", "upcoming")
            if (status == "inProgress" && !foundInProgress) {
                displayCourses.add(c)
                foundInProgress = true
            } else if (status == "upcoming") {
                displayCourses.add(c)
            }
            if (displayCourses.size >= 2) break
        }
        // If no in-progress course, ensure we show up to 2 upcoming courses
        if (!foundInProgress) {
            displayCourses.clear()
            for (i in 0 until courses.length()) {
                val c = courses.getJSONObject(i)
                if (c.optString("status", "upcoming") == "upcoming") {
                    displayCourses.add(c)
                }
                if (displayCourses.size >= 2) break
            }
        }

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .cornerRadius(16.dp)
                .background(ColorProvider(R.color.widget_background))
                .clickable(actionStartActivity(launchIntent))
                .padding(10.dp),
        ) {
            Text(
                text = title,
                style = TextStyle(
                    color = ColorProvider(R.color.widget_header_default),
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                ),
                maxLines = 1
            )
            Text(
                text = "$date  $week",
                style = TextStyle(
                    color = ColorProvider(R.color.widget_text_secondary),
                    fontSize = 11.sp
                ),
                maxLines = 1
            )

            Spacer(modifier = GlanceModifier.height(8.dp))

            if (displayCourses.isEmpty()) {
                Box(
                    modifier = GlanceModifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = emptyText,
                        style = TextStyle(
                            color = ColorProvider(R.color.widget_text_secondary),
                            fontSize = 13.sp
                        )
                    )
                }
            } else {
                for (i in displayCourses.indices) {
                    CourseCardSmall(displayCourses[i])
                    if (i < displayCourses.size - 1) {
                        Spacer(modifier = GlanceModifier.height(6.dp))
                    }
                }
            }
        }
    }

    @Composable
    private fun MediumWidget(data: WidgetCourseData?, launchIntent: Intent) {
        val courses = data?.courses ?: JSONArray()
        val title = data?.headerTitle ?: "不高山上"
        val date = data?.dateText ?: ""
        val week = data?.weekText ?: ""
        val emptyText = data?.emptyText ?: "今天没有课程"

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .cornerRadius(16.dp)
                .background(ColorProvider(R.color.widget_background))
                .clickable(actionStartActivity(launchIntent))
                .padding(12.dp),
        ) {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_header_default),
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp
                    ),
                    maxLines = 1,
                    modifier = GlanceModifier.defaultWeight()
                )
                Text(
                    text = "$date  $week",
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_text_secondary),
                        fontSize = 12.sp
                    ),
                    maxLines = 1
                )
            }

            Spacer(modifier = GlanceModifier.height(10.dp))

            if (courses.length() == 0) {
                Box(
                    modifier = GlanceModifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = emptyText,
                        style = TextStyle(
                            color = ColorProvider(R.color.widget_text_secondary),
                            fontSize = 13.sp
                        )
                    )
                }
            } else {
                val limit = 2
                Column(modifier = GlanceModifier.fillMaxSize()) {
                    for (i in 0 until minOf(courses.length(), limit)) {
                        CourseCardMedium(courses.getJSONObject(i))
                        if (i < minOf(courses.length(), limit) - 1) {
                            Spacer(modifier = GlanceModifier.height(8.dp))
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun LargeWidget(data: WidgetCourseData?, launchIntent: Intent) {
        val courses = data?.courses ?: JSONArray()
        val title = data?.headerTitle ?: "不高山上"
        val date = data?.dateText ?: ""
        val week = data?.weekText ?: ""
        val emptyText = data?.emptyText ?: "今天没有课程"

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .cornerRadius(16.dp)
                .background(ColorProvider(R.color.widget_background))
                .clickable(actionStartActivity(launchIntent))
                .padding(12.dp),
        ) {
            Text(
                text = title,
                style = TextStyle(
                    color = ColorProvider(R.color.widget_header_default),
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp
                ),
                maxLines = 1
            )
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = week,
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_text_secondary),
                        fontSize = 12.sp
                    ),
                    maxLines = 1,
                    modifier = GlanceModifier.defaultWeight()
                )
                Text(
                    text = date,
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_text_secondary),
                        fontSize = 12.sp
                    ),
                    maxLines = 1
                )
            }

            Spacer(modifier = GlanceModifier.height(10.dp))

            if (courses.length() == 0) {
                Box(
                    modifier = GlanceModifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = emptyText,
                            style = TextStyle(
                                color = ColorProvider(R.color.widget_text_secondary),
                                fontWeight = FontWeight.Medium,
                                fontSize = 15.sp
                            )
                        )
                        Spacer(modifier = GlanceModifier.height(4.dp))
                        Text(
                            text = "享受轻松的一天吧",
                            style = TextStyle(
                                color = ColorProvider(R.color.widget_text_secondary),
                                fontSize = 12.sp
                            )
                        )
                    }
                }
            } else {
                val limit = 4
                Column(modifier = GlanceModifier.fillMaxSize()) {
                    for (i in 0 until minOf(courses.length(), limit)) {
                        CourseCardLarge(courses.getJSONObject(i))
                        if (i < minOf(courses.length(), limit) - 1) {
                            Spacer(modifier = GlanceModifier.height(6.dp))
                        }
                    }
                }
            }
        }
    }

    // ── Course card composables ──────────────────────────────────────

    @Composable
    private fun CourseCardSmall(course: JSONObject) {
        val name = course.optString("name", "")
        val startTime = course.optString("startTime", "")
        val location = course.optString("location", "")

        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .cornerRadius(12.dp)
                .background(ColorProvider(R.color.widget_card_background))
                .padding(8.dp),
            verticalAlignment = Alignment.Top
        ) {
            Box(
                modifier = GlanceModifier
                    .width(4.dp)
                    .height(28.dp)
                    .cornerRadius(2.dp)
                    .background(ColorProvider(R.color.widget_header_default))
            ) {}
            Spacer(modifier = GlanceModifier.width(8.dp))
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = name,
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_text_primary),
                        fontWeight = FontWeight.Medium,
                        fontSize = 13.sp
                    ),
                    maxLines = 1
                )
                Text(
                    text = "$startTime  $location",
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_text_secondary),
                        fontSize = 10.sp
                    ),
                    maxLines = 2
                )
            }
        }
    }

    @Composable
    private fun CourseCardMedium(course: JSONObject) {
        val name = course.optString("name", "")
        val startTime = course.optString("startTime", "")
        val endTime = course.optString("endTime", "")
        val location = course.optString("location", "")

        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .cornerRadius(12.dp)
                .background(ColorProvider(R.color.widget_card_background))
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = GlanceModifier
                    .width(4.dp)
                    .height(36.dp)
                    .cornerRadius(2.dp)
                    .background(ColorProvider(R.color.widget_header_default))
            ) {}
            Spacer(modifier = GlanceModifier.width(10.dp))
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = name,
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_text_primary),
                        fontWeight = FontWeight.Medium,
                        fontSize = 14.sp
                    ),
                    maxLines = 1
                )
                Text(
                    text = "$startTime - $endTime  $location",
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_text_secondary),
                        fontSize = 12.sp
                    ),
                    maxLines = 1
                )
            }
        }
    }

    @Composable
    private fun CourseCardLarge(course: JSONObject) {
        val name = course.optString("name", "")
        val startTime = course.optString("startTime", "")
        val endTime = course.optString("endTime", "")
        val location = course.optString("location", "")
        val ss = course.optInt("startSection", 0)
        val es = course.optInt("endSection", 0)
        val section = if (ss == es) "第${ss}节" else "第${ss}-${es}节"

        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .cornerRadius(10.dp)
                .background(ColorProvider(R.color.widget_card_background))
                .padding(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = GlanceModifier
                    .width(4.dp)
                    .height(36.dp)
                    .cornerRadius(2.dp)
                    .background(ColorProvider(R.color.widget_header_default))
            ) {}
            Spacer(modifier = GlanceModifier.width(10.dp))
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = name,
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_text_primary),
                        fontWeight = FontWeight.Medium,
                        fontSize = 14.sp
                    ),
                    maxLines = 1
                )
                Text(
                    text = "$startTime - $endTime  $section",
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_text_secondary),
                        fontSize = 11.sp
                    ),
                    maxLines = 1
                )
                Text(
                    text = location,
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_text_secondary),
                        fontSize = 11.sp
                    ),
                    maxLines = 1
                )
            }
        }
    }
}

// ── Widget Receivers ────────────────────────────────────────────────

class CourseWidgetReceiverSmall : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = CourseGlanceWidget()
}

class CourseWidgetReceiverMedium : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = CourseGlanceWidget()
}

class CourseWidgetReceiverLarge : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = CourseGlanceWidget()
}
