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
import java.text.SimpleDateFormat
import java.util.Locale

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
    val isTomorrow: Boolean = false,
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

            courses = attachTimesAndStatuses(courses, timeSlots, currentTimeMinutes, false)
            var showingTomorrow = false
            var tomorrowCal: Calendar? = null
            var weekForTomorrow = currentWeek
            // If no remaining courses today and user enabled the setting, try to show tomorrow's courses
            if (courses.length() == 0) {
                try {
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    // Flutter SharedPreferences stores keys with a "flutter." prefix on Android.
                    val rawKey = "widget_show_tomorrow"
                    val flutterKey = "flutter.$rawKey"
                    var showTomorrow = prefs?.getBoolean(flutterKey, false) ?: false
                    // Backward compatibility: also check unprefixed key
                    if (!showTomorrow) {
                        showTomorrow = prefs?.getBoolean(rawKey, false) ?: false
                    }
                    if (showTomorrow) {
                        tomorrowCal = Calendar.getInstance().apply { add(Calendar.DATE, 1) }
                        val nextDayOfWeek = (tomorrowCal!!.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
                        weekForTomorrow = computeWeekForDate(semesterStartDate, totalWeeks, tomorrowCal!!)
                        var tomorrowCourses = queryCourses(db, currentScheduleId, nextDayOfWeek, weekForTomorrow)
                        if (tomorrowCourses.length() == 0 && currentScheduleId != "default") {
                            tomorrowCourses = queryCourses(db, "default", nextDayOfWeek, weekForTomorrow)
                        }
                        if (tomorrowCourses.length() > 0) {
                            // attach times and mark as upcoming
                            courses = attachTimesAndStatuses(tomorrowCourses, timeSlots, null, true)
                            showingTomorrow = true
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to read widget setting", e)
                }
            }

            var month = now.get(Calendar.MONTH) + 1
            var day = now.get(Calendar.DAY_OF_MONTH)
            val locale = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                context.resources.configuration.locales.get(0)
            } else {
                context.resources.configuration.locale
            }

            val dayFormat = SimpleDateFormat("EEE", locale)
            var dateText = "$month/$day ${dayFormat.format(now.time)}"
            if (showingTomorrow && tomorrowCal != null) {
                month = tomorrowCal.get(Calendar.MONTH) + 1
                day = tomorrowCal.get(Calendar.DAY_OF_MONTH)
                val dayName = dayFormat.format(tomorrowCal.time)
                val tomorrowLabel = context.getString(R.string.tomorrow)
                dateText = "$month/$day $dayName $tomorrowLabel"
            }

            val weekNumber = if (showingTomorrow) weekForTomorrow else currentWeek
            val weekText = context.getString(R.string.widget_week_format, weekNumber)

            val themeColor = 0xFF2196F3.toInt()

            return WidgetCourseData(
                courses = courses,
                dateText = dateText,
                weekText = weekText,
                headerTitle = "不高山上",
                emptyText = context.getString(R.string.widget_empty_today),
                sectionPrefix = "第",
                sectionSuffix = "节",
                themeColor = themeColor,
                isTomorrow = showingTomorrow,
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

    private fun attachTimesAndStatuses(
        courses: JSONArray,
        timeSlots: JSONArray?,
        currentTimeMinutes: Int?,
        forceUpcoming: Boolean = false
    ): JSONArray {
        val updated = JSONArray()
        for (i in 0 until courses.length()) {
            val c = courses.getJSONObject(i)
            val ss = c.optInt("startSection", 0)
            val es = c.optInt("endSection", 0)
            c.put("startTime", formatTime(timeSlots, ss))
            c.put("endTime", formatTime(timeSlots, es, isEnd = true))

            if (!forceUpcoming && currentTimeMinutes != null) {
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
            } else {
                // For tomorrow or forced upcoming, mark as upcoming
                c.put("status", "upcoming")
            }

            updated.put(c)
        }
        return updated
    }

    private fun isCourseActive(week: Int, startWeek: Int, endWeek: Int, weekType: Int): Boolean {
        if (week < startWeek || week > endWeek) return false
        if (weekType == 1 && week % 2 == 0) return false
        if (weekType == 2 && week % 2 == 1) return false
        return true
    }

    private fun computeCurrentWeek(semesterStartDate: String, totalWeeks: Int): Int {
        if (semesterStartDate.isEmpty()) return 1
        if (totalWeeks <= 0) return 1
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
        val maxWeek = if (totalWeeks >= 1) totalWeeks else week
        return week.coerceIn(1, maxWeek)
    }

    private fun computeWeekForDate(semesterStartDate: String, totalWeeks: Int, cal: Calendar): Int {
        if (semesterStartDate.isEmpty()) return 1
        if (totalWeeks <= 0) return 1
        val parts = semesterStartDate.split("-")
        if (parts.size != 3) return 1
        val startCal = Calendar.getInstance().apply {
            set(parts[0].toInt(), parts[1].toInt() - 1, parts[2].toInt(), 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val target = Calendar.getInstance().apply {
            timeInMillis = cal.timeInMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (target.before(startCal)) return 1
        val days = ((target.timeInMillis - startCal.timeInMillis) / (1000 * 60 * 60 * 24)).toInt()
        val week = days / 7 + 1
        val maxWeek = if (totalWeeks >= 1) totalWeeks else week
        return week.coerceIn(1, maxWeek)
    }

    private fun formatTime(timeSlots: JSONArray?, section: Int, isEnd: Boolean = false): String {
        if (timeSlots == null || section < 1 || section > timeSlots.length()) return "--:--"
        val slot = timeSlots.getJSONObject(section - 1)
        val key = if (isEnd) "endTime" else "startTime"
        val time = slot.optJSONObject(key) ?: return "--:--"
        val h = time.optInt("hour", 0).toString().padStart(2, '0')
        val m = time.optInt("minute", 0).toString().padStart(2, '0')
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
                    isSmall -> SmallWidget(data, launchIntent, data?.emptyText ?: context.getString(R.string.widget_empty_today))
                    isLarge -> LargeWidget(data, launchIntent, data?.emptyText ?: context.getString(R.string.widget_empty_today))
                    else -> MediumWidget(data, launchIntent, data?.emptyText ?: context.getString(R.string.widget_empty_today))
                }
            }
        }
    }

    @Composable
    private fun SmallWidget(data: WidgetCourseData?, launchIntent: Intent, emptyTextParam: String) {
        val courses = data?.courses ?: JSONArray()
        val title = data?.headerTitle ?: "不高山上"
        val date = data?.dateText ?: ""
        val week = data?.weekText ?: ""
        val emptyText = data?.emptyText ?: emptyTextParam

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
                    val isTomorrow = data?.isTomorrow ?: false
                    for (i in displayCourses.indices) {
                        CourseCardSmall(displayCourses[i], isTomorrow)
                    if (i < displayCourses.size - 1) {
                        Spacer(modifier = GlanceModifier.height(6.dp))
                    }
                }
            }
        }
    }

    @Composable
    private fun MediumWidget(data: WidgetCourseData?, launchIntent: Intent, emptyTextParam: String) {
        val courses = data?.courses ?: JSONArray()
        val title = data?.headerTitle ?: "不高山上"
        val date = data?.dateText ?: ""
        val week = data?.weekText ?: ""
        val emptyText = data?.emptyText ?: emptyTextParam

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
                    val isTomorrow = data?.isTomorrow ?: false
                    for (i in 0 until minOf(courses.length(), limit)) {
                        CourseCardMedium(courses.getJSONObject(i), isTomorrow)
                        if (i < minOf(courses.length(), limit) - 1) {
                            Spacer(modifier = GlanceModifier.height(8.dp))
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun LargeWidget(data: WidgetCourseData?, launchIntent: Intent, emptyTextParam: String) {
        val courses = data?.courses ?: JSONArray()
        val title = data?.headerTitle ?: "不高山上"
        val date = data?.dateText ?: ""
        val week = data?.weekText ?: ""
        val emptyText = data?.emptyText ?: emptyTextParam

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
                    val isTomorrow = data?.isTomorrow ?: false
                    for (i in 0 until minOf(courses.length(), limit)) {
                        CourseCardLarge(courses.getJSONObject(i), isTomorrow)
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
    private fun CourseCardSmall(course: JSONObject, isTomorrow: Boolean) {
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
                val leftColor = if (isTomorrow) R.color.widget_tomorrow_accent else R.color.widget_header_default
                val nameColor = if (isTomorrow) R.color.widget_tomorrow_text_primary else R.color.widget_text_primary
                val metaColor = if (isTomorrow) R.color.widget_tomorrow_text_secondary else R.color.widget_text_secondary

                Box(
                modifier = GlanceModifier
                    .width(4.dp)
                    .height(28.dp)
                    .cornerRadius(2.dp)
                    .background(ColorProvider(leftColor))
            ) {}
            Spacer(modifier = GlanceModifier.width(8.dp))
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = name,
                    style = TextStyle(
                        color = ColorProvider(nameColor),
                        fontWeight = FontWeight.Medium,
                        fontSize = 13.sp
                    ),
                    maxLines = 1
                )
                Text(
                    text = "$startTime  $location",
                    style = TextStyle(
                        color = ColorProvider(metaColor),
                        fontSize = 10.sp
                    ),
                    maxLines = 2
                )
            }
        }
    }

    @Composable
    private fun CourseCardMedium(course: JSONObject, isTomorrow: Boolean) {
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
                val leftColor = if (isTomorrow) R.color.widget_tomorrow_accent else R.color.widget_header_default
                val nameColor = if (isTomorrow) R.color.widget_tomorrow_text_primary else R.color.widget_text_primary
                val metaColor = if (isTomorrow) R.color.widget_tomorrow_text_secondary else R.color.widget_text_secondary

                Box(
                modifier = GlanceModifier
                    .width(4.dp)
                    .height(36.dp)
                    .cornerRadius(2.dp)
                    .background(ColorProvider(leftColor))
            ) {}
            Spacer(modifier = GlanceModifier.width(10.dp))
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = name,
                    style = TextStyle(
                        color = ColorProvider(nameColor),
                        fontWeight = FontWeight.Medium,
                        fontSize = 14.sp
                    ),
                    maxLines = 1
                )
                Text(
                    text = "$startTime - $endTime  $location",
                    style = TextStyle(
                        color = ColorProvider(metaColor),
                        fontSize = 12.sp
                    ),
                    maxLines = 1
                )
            }
        }
    }

    @Composable
    private fun CourseCardLarge(course: JSONObject, isTomorrow: Boolean) {
        val name = course.optString("name", "")
        val startTime = course.optString("startTime", "")
        val endTime = course.optString("endTime", "")
        val location = course.optString("location", "")
        val teacher = course.optString("teacher", "")
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
                val leftColor = if (isTomorrow) R.color.widget_tomorrow_accent else R.color.widget_header_default
                val nameColor = if (isTomorrow) R.color.widget_tomorrow_text_primary else R.color.widget_text_primary
                val metaColor = if (isTomorrow) R.color.widget_tomorrow_text_secondary else R.color.widget_text_secondary

                Box(
                modifier = GlanceModifier
                    .width(4.dp)
                    .height(36.dp)
                    .cornerRadius(2.dp)
                    .background(ColorProvider(leftColor))
            ) {}
            Spacer(modifier = GlanceModifier.width(10.dp))
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = name,
                    style = TextStyle(
                        color = ColorProvider(nameColor),
                        fontWeight = FontWeight.Medium,
                        fontSize = 14.sp
                    ),
                    maxLines = 1
                )
                Text(
                    text = "$startTime - $endTime  $section" + if (teacher.isNotEmpty()) "  $teacher" else "",
                    style = TextStyle(
                        color = ColorProvider(metaColor),
                        fontSize = 11.sp
                    ),
                    maxLines = 1
                )
                Text(
                    text = location,
                    style = TextStyle(
                        color = ColorProvider(metaColor),
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
