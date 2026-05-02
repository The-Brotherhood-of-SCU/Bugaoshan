package io.github.the_brotherhood_of_scu.bugaoshan.db

import io.github.the_brotherhood_of_scu.bugaoshan.model.Course
import io.github.the_brotherhood_of_scu.bugaoshan.model.ScheduleConfig
import io.github.the_brotherhood_of_scu.bugaoshan.model.WeekType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class DatabaseService(private val database: AppDatabase) {
    private val json = Json { ignoreUnknownKeys = true }

    // In-memory cache
    private var currentScheduleId: String = "default"
    private var schedulesCache: List<ScheduleConfig> = emptyList()
    private var coursesCache: List<Course> = emptyList()

    suspend fun init() = withContext(Dispatchers.Default) {
        // Load current schedule ID
        val metaRow = database.metadataQueries.getMetadata(KEY_CURRENT_SCHEDULE_ID).executeAsOneOrNull()
        if (metaRow != null) {
            currentScheduleId = metaRow
        }

        // Ensure default schedule exists
        val scheduleCount = database.schedulesQueries.getAllSchedules().executeAsList()
        if (scheduleCount.isEmpty()) {
            val defaultConfig = ScheduleConfig.defaultConfig()
            database.schedulesQueries.insertSchedule(
                defaultConfig.id,
                json.encodeToString(defaultConfig)
            )
            database.metadataQueries.setMetadata(KEY_CURRENT_SCHEDULE_ID, defaultConfig.id)
        }

        // Load caches
        loadSchedulesCache()
        loadCoursesCache()
    }

    private fun loadSchedulesCache() {
        val rows = database.schedulesQueries.getAllSchedules().executeAsList()
        schedulesCache = rows.map { row ->
            json.decodeFromString<ScheduleConfig>(row.config_json)
        }
    }

    private fun loadCoursesCache() {
        val rows = database.coursesQueries.getCoursesBySchedule(currentScheduleId).executeAsList()
        coursesCache = rows.map { row ->
            Course(
                id = row.id,
                name = row.name ?: "",
                teacher = row.teacher ?: "",
                location = row.location ?: "",
                startWeek = row.start_week?.toInt() ?: 1,
                endWeek = row.end_week?.toInt() ?: 20,
                dayOfWeek = row.day_of_week?.toInt() ?: 1,
                startSection = row.start_section?.toInt() ?: 1,
                endSection = row.end_section?.toInt() ?: 2,
                colorValue = row.color_value ?: 0xFF2196F3,
                weekType = WeekType.fromIndex(row.week_type?.toInt() ?: 0),
            )
        }
    }

    // ==================== Schedule Management ====================

    fun getCurrentScheduleId(): String = currentScheduleId

    suspend fun switchSchedule(scheduleId: String) = withContext(Dispatchers.Default) {
        currentScheduleId = scheduleId
        database.metadataQueries.setMetadata(KEY_CURRENT_SCHEDULE_ID, scheduleId)
        loadCoursesCache()
    }

    fun getAllSchedules(): List<ScheduleConfig> = schedulesCache

    fun getScheduleConfig(): ScheduleConfig {
        return schedulesCache.firstOrNull { it.id == currentScheduleId }
            ?: schedulesCache.firstOrNull()
            ?: ScheduleConfig.defaultConfig()
    }

    suspend fun saveScheduleConfig(config: ScheduleConfig) = withContext(Dispatchers.Default) {
        val existing = database.schedulesQueries.getScheduleById(config.id).executeAsOneOrNull()
        val jsonStr = json.encodeToString(config)
        if (existing != null) {
            database.schedulesQueries.updateSchedule(jsonStr, config.id)
        } else {
            database.schedulesQueries.insertSchedule(config.id, jsonStr)
        }
        loadSchedulesCache()
    }

    suspend fun addSchedule(config: ScheduleConfig) = withContext(Dispatchers.Default) {
        database.schedulesQueries.insertSchedule(config.id, json.encodeToString(config))
        loadSchedulesCache()
    }

    suspend fun deleteSchedule(scheduleId: String) = withContext(Dispatchers.Default) {
        database.coursesQueries.deleteCoursesBySchedule(scheduleId)
        database.schedulesQueries.deleteSchedule(scheduleId)
        loadSchedulesCache()

        if (currentScheduleId == scheduleId && schedulesCache.isNotEmpty()) {
            switchSchedule(schedulesCache.first().id)
        }
    }

    // ==================== Courses ====================

    fun getCourses(): List<Course> = coursesCache

    suspend fun getCoursesAsync(scheduleId: String = currentScheduleId): List<Course> = withContext(Dispatchers.Default) {
        val rows = database.coursesQueries.getCoursesBySchedule(scheduleId).executeAsList()
        rows.map { row ->
            Course(
                id = row.id,
                name = row.name ?: "",
                teacher = row.teacher ?: "",
                location = row.location ?: "",
                startWeek = row.start_week?.toInt() ?: 1,
                endWeek = row.end_week?.toInt() ?: 20,
                dayOfWeek = row.day_of_week?.toInt() ?: 1,
                startSection = row.start_section?.toInt() ?: 1,
                endSection = row.end_section?.toInt() ?: 2,
                colorValue = row.color_value ?: 0xFF2196F3,
                weekType = WeekType.fromIndex(row.week_type?.toInt() ?: 0),
            )
        }
    }

    suspend fun addCourse(course: Course) = withContext(Dispatchers.Default) {
        database.coursesQueries.insertCourse(
            course.id,
            currentScheduleId,
            course.name,
            course.teacher,
            course.location,
            course.startWeek.toLong(),
            course.endWeek.toLong(),
            course.dayOfWeek.toLong(),
            course.startSection.toLong(),
            course.endSection.toLong(),
            course.colorValue,
            course.weekType.ordinal.toLong(),
        )
        loadCoursesCache()
    }

    suspend fun updateCourse(course: Course) = withContext(Dispatchers.Default) {
        database.coursesQueries.updateCourse(
            course.name,
            course.teacher,
            course.location,
            course.startWeek.toLong(),
            course.endWeek.toLong(),
            course.dayOfWeek.toLong(),
            course.startSection.toLong(),
            course.endSection.toLong(),
            course.colorValue,
            course.weekType.ordinal.toLong(),
            course.id,
        )
        loadCoursesCache()
    }

    suspend fun deleteCourse(courseId: String) = withContext(Dispatchers.Default) {
        database.coursesQueries.deleteCourse(courseId)
        loadCoursesCache()
    }

    fun hasConflict(course: Course, excludeId: String? = null): Boolean {
        return coursesCache.any { it.conflictsWith(course, excludeId = excludeId) }
    }

    // ==================== Clear ====================

    suspend fun clearAllCourseData() = withContext(Dispatchers.Default) {
        database.coursesQueries.deleteCoursesBySchedule(currentScheduleId)
        database.schedulesQueries.deleteSchedule(currentScheduleId)
        database.metadataQueries.deleteMetadata(KEY_CURRENT_SCHEDULE_ID)

        // Re-create default schedule
        val defaultConfig = ScheduleConfig.defaultConfig()
        database.schedulesQueries.insertSchedule(defaultConfig.id, json.encodeToString(defaultConfig))
        database.metadataQueries.setMetadata(KEY_CURRENT_SCHEDULE_ID, defaultConfig.id)
        currentScheduleId = defaultConfig.id

        loadSchedulesCache()
        loadCoursesCache()
    }

    companion object {
        private const val KEY_CURRENT_SCHEDULE_ID = "currentScheduleId"
    }
}
