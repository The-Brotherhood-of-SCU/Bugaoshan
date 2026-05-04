package io.github.the_brotherhood_of_scu.bugaoshan.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.github.the_brotherhood_of_scu.bugaoshan.db.DatabaseService
import io.github.the_brotherhood_of_scu.bugaoshan.model.Course
import io.github.the_brotherhood_of_scu.bugaoshan.model.ScheduleConfig
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class CourseViewModel(private val db: DatabaseService) : ViewModel() {
    private val _courses = MutableStateFlow<List<Course>>(emptyList())
    val courses: StateFlow<List<Course>> = _courses.asStateFlow()

    private val _scheduleConfig = MutableStateFlow(ScheduleConfig.defaultConfig())
    val scheduleConfig: StateFlow<ScheduleConfig> = _scheduleConfig.asStateFlow()

    private val _allSchedules = MutableStateFlow<List<ScheduleConfig>>(emptyList())
    val allSchedules: StateFlow<List<ScheduleConfig>> = _allSchedules.asStateFlow()

    private val _currentWeek = MutableStateFlow(1)
    val currentWeek: StateFlow<Int> = _currentWeek.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private var onCoursesChanged: (() -> Unit)? = null

    fun setOnCoursesChanged(callback: () -> Unit) {
        onCoursesChanged = callback
    }

    private var dbInitialized = false

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                if (!dbInitialized) {
                    db.init()
                    dbInitialized = true
                }
                _courses.value = db.getCourses()
                _allSchedules.value = db.getAllSchedules()
                val config = db.getScheduleConfig()
                _scheduleConfig.value = config
                _currentWeek.value = config.getCurrentWeek()
            } catch (e: Exception) {
                println("CourseViewModel: failed to load data: ${e.message}")
            } finally {
                _isLoading.value = false
                onCoursesChanged?.invoke()
            }
        }
    }

    fun switchSchedule(scheduleId: String) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                db.switchSchedule(scheduleId)
                loadData()
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun addSchedule(config: ScheduleConfig) {
        viewModelScope.launch {
            db.addSchedule(config)
            _allSchedules.value = db.getAllSchedules()
            switchSchedule(config.id)
        }
    }

    fun deleteSchedule(scheduleId: String) {
        viewModelScope.launch {
            db.deleteSchedule(scheduleId)
            loadData()
        }
    }

    fun addCourse(course: Course) {
        viewModelScope.launch {
            db.addCourse(course)
            _courses.value = db.getCourses()
            onCoursesChanged?.invoke()
        }
    }

    fun updateCourse(course: Course) {
        viewModelScope.launch {
            db.updateCourse(course)
            _courses.value = db.getCourses()
            onCoursesChanged?.invoke()
        }
    }

    fun deleteCourse(courseId: String) {
        viewModelScope.launch {
            db.deleteCourse(courseId)
            _courses.value = db.getCourses()
            onCoursesChanged?.invoke()
        }
    }

    fun updateScheduleConfig(config: ScheduleConfig) {
        viewModelScope.launch {
            db.saveScheduleConfig(config)
            _scheduleConfig.value = config
            _allSchedules.value = db.getAllSchedules()
            _currentWeek.value = config.getCurrentWeek()
            onCoursesChanged?.invoke()
        }
    }

    fun updateCurrentWeek(week: Int) {
        val totalWeeks = _scheduleConfig.value.totalWeeks
        _currentWeek.value = week.coerceIn(1, totalWeeks)
    }

    fun hasConflict(course: Course, excludeId: String? = null): Boolean {
        return db.hasConflict(course, excludeId = excludeId)
    }

    fun clearAllData() {
        viewModelScope.launch {
            db.clearAllCourseData()
            loadData()
        }
    }
}
