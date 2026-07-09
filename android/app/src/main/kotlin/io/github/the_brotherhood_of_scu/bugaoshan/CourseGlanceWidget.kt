package io.github.the_brotherhood_of_scu.bugaoshan

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import android.content.Intent
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
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
import java.util.LinkedHashMap
import kotlin.math.roundToInt
import java.text.SimpleDateFormat
import java.util.Locale
    

// Parse appWidgetId token from GlanceId string
private fun parseAppWidgetId(idString: String): Int? {
    // Prefer explicit token match like "appWidgetId=123" or "appWidgetId: 123"
    val tokenRegex = Regex("appWidgetId\\W*=?\\W*(\\d+)", RegexOption.IGNORE_CASE)
    tokenRegex.find(idString)?.let { m -> return m.groupValues.getOrNull(1)?.toIntOrNull() }

    // Common alternate form: AppWidgetId(123)
    val altRegex = Regex("AppWidgetId\\W*\\(\\s*(\\d+)\\s*\\)", RegexOption.IGNORE_CASE)
    altRegex.find(idString)?.let { m -> return m.groupValues.getOrNull(1)?.toIntOrNull() }

    // Fallback: no reliable id token found -> return null to avoid accidental matches
    return null
}

// Layout thresholds (units: dp for comparisons using integer dp values)
private const val TOTAL_HORIZONTAL_PADDING_DP = 24 // 12dp each side
private const val TITLE_ONE_LINE_WIDTH_DP = 180
private const val TITLE_BAR_HEIGHT_DP = 80
private const val VERTICAL_PADDING_DP = 24
private const val CARD_MODE_HEIGHT_THRESHOLD_DP = 100
private const val SHORT_TIME_WIDTH_THRESHOLD_DP = 200

// Visual sizes and spacing (Dp/Sp)
private val WIDGET_CORNER_RADIUS_DP = 16.dp
private val CARD_CORNER_RADIUS_DP = 12.dp
private val CARD_INDICATOR_WIDTH_DP = 4.dp
private val CARD_INDICATOR_HEIGHT_DP = 36.dp
private val CONTENT_PADDING_DP = 12.dp
private val CARD_PADDING_DP = 8.dp
private val CONTENT_SPACER_HEIGHT_DP = 10.dp
private val ITEM_SPACER_HEIGHT_DP = 0.dp
private val ITEM_VERTICAL_PADDING_DP = 2.dp

private val HEADER_FONT_SIZE_SP = 15.sp
private val TITLE_FONT_SIZE_SP = 14.sp
private val META_FONT_SIZE_SP = 13.sp
private val META_SMALL_FONT_SIZE_SP = 11.sp
private val EMPTY_FONT_SIZE_SP = 13.sp

// Cached layout parameters per widget instance
data class CachedLayout(
    val width: Int,
    val height: Int,
    val oneLineTitle: Boolean,
    val cardMode: Int // 2 = two-line (time+section on first line, location on second), 1 = single-line (time+location same line)
)

object WidgetLayoutCache {
    private const val MAX_ENTRIES = 64

    // accessOrder = true for LRU behavior
    private val map: LinkedHashMap<Int, CachedLayout> = object : LinkedHashMap<Int, CachedLayout>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Int, CachedLayout>?): Boolean {
            return this.size > MAX_ENTRIES
        }
    }

    @Synchronized
    fun getIfSameSize(appWidgetId: Int?, w: Int, h: Int): CachedLayout? {
        if (appWidgetId == null) return null
        val c = map[appWidgetId] ?: return null
        return if (c.width == w && c.height == h) c else null
    }

    @Synchronized
    fun put(appWidgetId: Int?, layout: CachedLayout) {
        if (appWidgetId == null) return
        map[appWidgetId] = layout
    }

    @Synchronized
    fun remove(appWidgetId: Int) {
        map.remove(appWidgetId)
    }

    @Synchronized
    fun clear() {
        map.clear()
    }
}

// Data loaded from SQLite for the widget
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

// SQLite data loader
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
            if (courses.length() == 0) {
                try {
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val rawKey = "widget_show_tomorrow"
                    val flutterKey = "flutter.$rawKey"
                    var showTomorrow = prefs?.getBoolean(flutterKey, false) ?: false
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
                headerTitle = context.getString(R.string.widget_header_title),
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
                val endSlot = getSlotEndTime(timeSlots, es)
                if (endSlot != null) {
                    val endMinutes = endSlot.first * 60 + endSlot.second
                    if (currentTimeMinutes >= endMinutes) continue
                }
                val startSlot = getSlotStartTime(timeSlots, ss)
                if (startSlot != null && endSlot != null) {
                    val startMinutes = startSlot.first * 60 + startSlot.second
                    val endMinutes = endSlot.first * 60 + endSlot.second
                    c.put("status", if (currentTimeMinutes in startMinutes until endMinutes) "inProgress" else "upcoming")
                } else {
                    c.put("status", "upcoming")
                }
            } else {
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

// Glance Widget
class CourseGlanceWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = WidgetDataLoader.load(context)
        // Use getLaunchIntentForPackage so Android resolves to the currently
        // enabled activity / activity-alias (fixes widget click after icon switch)
        val launchIntent = (context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
                setPackage(context.packageName)
            }).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        // prepare localized format strings from Android resources
        val headerDefault = context.getString(R.string.widget_header_title)
        val sectionSingleFmt = context.getString(R.string.widget_section_single)
        val sectionRangeFmt = context.getString(R.string.widget_section_range)
        val emptyDefault = context.getString(R.string.widget_empty_today)

        provideContent {
            GlanceTheme {
                val size = LocalSize.current
                val widthDp = size.width.value.roundToInt()
                val heightDp = size.height.value.roundToInt()

                val parsedId = try {
                    parseAppWidgetId(id.toString())
                } catch (e: Exception) { null }

                val cached = WidgetLayoutCache.getIfSameSize(parsedId, widthDp, heightDp)

                val layoutParams = if (cached != null) {
                    cached
                } else {
                    val availableWidth = widthDp - TOTAL_HORIZONTAL_PADDING_DP
                        val oneLineTitle = availableWidth >= TITLE_ONE_LINE_WIDTH_DP

                        // Fixed title bar height estimation (avoids dynamic calculation)
                        val titleBarHeight = TITLE_BAR_HEIGHT_DP
                        val verticalPadding = VERTICAL_PADDING_DP
                        val availableForCards = heightDp - titleBarHeight - verticalPadding
                        val cardMode = if (availableForCards > CARD_MODE_HEIGHT_THRESHOLD_DP) 2 else 1

                    val computed = CachedLayout(widthDp, heightDp, oneLineTitle, cardMode)
                    WidgetLayoutCache.put(parsedId, computed)
                    computed
                }

                // pass Android context and resource ids to allow resource-based formatting inside composables
                UnifiedWidget(
                    context,
                    data,
                    launchIntent,
                    layoutParams,
                    headerDefault,
                    R.string.widget_section_single,
                    R.string.widget_section_range,
                    R.string.widget_empty_today
                )
            }
        }
    }

    @Composable
    private fun UnifiedWidget(
        ctx: Context,
        data: WidgetCourseData?,
        launchIntent: Intent,
        layout: CachedLayout,
        headerDefault: String,
        sectionSingleRes: Int,
        sectionRangeRes: Int,
        emptyRes: Int
    ) {
        val courses = data?.courses ?: JSONArray()
        val title = if (!data?.headerTitle.isNullOrEmpty()) data!!.headerTitle else headerDefault
        val date = data?.dateText ?: ""
        val week = data?.weekText ?: ""
        val emptyText = data?.emptyText ?: ctx.getString(emptyRes)
        val isTomorrow = data?.isTomorrow ?: false

        val fullDate = if (week.isNotEmpty()) "$date  $week" else date

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .cornerRadius(WIDGET_CORNER_RADIUS_DP)
                .background(ColorProvider(R.color.widget_background))
                .clickable(actionStartActivity(launchIntent))
                .padding(CONTENT_PADDING_DP),
        ) {
            if (layout.oneLineTitle) {
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = title,
                        style = TextStyle(
                            color = ColorProvider(R.color.widget_header_default),
                            fontWeight = FontWeight.Bold,
                            fontSize = HEADER_FONT_SIZE_SP
                        ),
                        maxLines = 1,
                        modifier = GlanceModifier.defaultWeight()
                    )
                    Text(
                        text = fullDate,
                        style = TextStyle(
                            color = ColorProvider(R.color.widget_text_secondary),
                            fontSize = META_SMALL_FONT_SIZE_SP
                        ),
                        maxLines = 1
                    )
                }
            } else {
                Text(
                    text = title,
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_header_default),
                        fontWeight = FontWeight.Bold,
                        fontSize = HEADER_FONT_SIZE_SP
                    ),
                    maxLines = 1
                )
                Text(
                    text = fullDate,
                    style = TextStyle(
                        color = ColorProvider(R.color.widget_text_secondary),
                        fontSize = META_SMALL_FONT_SIZE_SP
                    ),
                    maxLines = 1
                )
            }

            Spacer(modifier = GlanceModifier.height(CONTENT_SPACER_HEIGHT_DP))

            if (courses.length() == 0) {
                Box(
                    modifier = GlanceModifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = emptyText,
                        style = TextStyle(
                            color = ColorProvider(R.color.widget_text_secondary),
                            fontSize = EMPTY_FONT_SIZE_SP
                        )
                    )
                }
            } else {
                LazyColumn(modifier = GlanceModifier.fillMaxSize()) {
                    items(courses.length()) { index ->
                        val course = courses.getJSONObject(index)
                        Box(modifier = GlanceModifier.padding(vertical = ITEM_VERTICAL_PADDING_DP)) {
                            CourseCard(
                                ctx,
                                course,
                                isTomorrow,
                                layout.cardMode,
                                layout.width,
                                layout.oneLineTitle,
                                sectionSingleRes,
                                sectionRangeRes
                            )
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun CourseCard(
        ctx: Context,
        course: JSONObject,
        isTomorrow: Boolean,
        cardMode: Int,
        parentWidthDp: Int,
        oneLineTitle: Boolean,
        sectionSingleRes: Int,
        sectionRangeRes: Int
    ) {
        val name = course.optString("name", "")
        val startTime = course.optString("startTime", "")
        val endTime = course.optString("endTime", "")
        val location = course.optString("location", "")
        val ss = course.optInt("startSection", 0)
        val es = course.optInt("endSection", 0)
        val section = if (ss > 0) {
            if (ss == es) ctx.getString(sectionSingleRes, ss)
            else ctx.getString(sectionRangeRes, ss, es)
        } else ""

        val leftColor = if (isTomorrow) R.color.widget_tomorrow_accent else R.color.widget_header_default
        val nameColor = if (isTomorrow) R.color.widget_tomorrow_text_primary else R.color.widget_text_primary
        val metaColor = if (isTomorrow) R.color.widget_tomorrow_text_secondary else R.color.widget_text_secondary

        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .cornerRadius(CARD_CORNER_RADIUS_DP)
                .background(ColorProvider(R.color.widget_card_background))
                .padding(CARD_PADDING_DP),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = GlanceModifier
                    .width(CARD_INDICATOR_WIDTH_DP)
                    .height(CARD_INDICATOR_HEIGHT_DP)
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
                        fontSize = TITLE_FONT_SIZE_SP
                    ),
                    maxLines = 1
                )

                if (cardMode == 2) {
                    // Two-line mode
                    Row(
                        modifier = GlanceModifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        val timeRange = if (endTime.isNotEmpty()) "$startTime - $endTime" else startTime
                        Text(
                            text = timeRange,
                            style = TextStyle(color = ColorProvider(metaColor), fontSize = META_FONT_SIZE_SP),
                            maxLines = 1,
                            modifier = GlanceModifier.defaultWeight()
                        )
                        // Section appears only when title is one-line and card mode is two-line
                        if (oneLineTitle && section.isNotEmpty()) {
                            Spacer(modifier = GlanceModifier.defaultWeight())
                            Text(
                                text = section,
                                style = TextStyle(color = ColorProvider(metaColor), fontSize = META_SMALL_FONT_SIZE_SP),
                                maxLines = 1
                            )
                        }
                    }
                    Text(
                        text = location,
                        style = TextStyle(color = ColorProvider(metaColor), fontSize = META_FONT_SIZE_SP),
                        maxLines = 2
                    )
                } else {
                    // Single-line mode: decide based on parent width
                    val useShortTime = parentWidthDp < SHORT_TIME_WIDTH_THRESHOLD_DP
                    val timeText = if (useShortTime) startTime else if (endTime.isNotEmpty()) "$startTime - $endTime" else startTime
                    val fontSize = if (useShortTime) META_SMALL_FONT_SIZE_SP else META_FONT_SIZE_SP
                    Text(
                        text = "$timeText  $location",
                        style = TextStyle(color = ColorProvider(metaColor), fontSize = fontSize),
                        maxLines = 2,
                        modifier = GlanceModifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

// Widget Receivers
class CourseWidgetReceiverSmall : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = CourseGlanceWidget()

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_LOCALE_CHANGED) {
            WidgetLayoutCache.clear()
            GlobalScope.launch(Dispatchers.Default) {
                try {
                    val manager = GlanceAppWidgetManager(context)
                    val ids = manager.getGlanceIds(CourseGlanceWidget::class.java)
                    ids.forEach { CourseGlanceWidget().update(context, it) }
                } catch (_: Exception) { /* best-effort */ }
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        for (id in appWidgetIds) WidgetLayoutCache.remove(id)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetLayoutCache.clear()
    }
}

class CourseWidgetReceiverMedium : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = CourseGlanceWidget()

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        for (id in appWidgetIds) WidgetLayoutCache.remove(id)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetLayoutCache.clear()
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_LOCALE_CHANGED) {
            WidgetLayoutCache.clear()
            GlobalScope.launch(Dispatchers.Default) {
                try {
                    val manager = GlanceAppWidgetManager(context)
                    val ids = manager.getGlanceIds(CourseGlanceWidget::class.java)
                    ids.forEach { CourseGlanceWidget().update(context, it) }
                } catch (_: Exception) { }
            }
        }
    }
}


class CourseWidgetReceiverLarge : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = CourseGlanceWidget()

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        for (id in appWidgetIds) WidgetLayoutCache.remove(id)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetLayoutCache.clear()
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_LOCALE_CHANGED) {
            WidgetLayoutCache.clear()
            GlobalScope.launch(Dispatchers.Default) {
                try {
                    val manager = GlanceAppWidgetManager(context)
                    val ids = manager.getGlanceIds(CourseGlanceWidget::class.java)
                    ids.forEach { CourseGlanceWidget().update(context, it) }
                } catch (_: Exception) { }
            }
        }
    }
}
