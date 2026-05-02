package io.github.the_brotherhood_of_scu.bugaoshan.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.russhwolf.settings.Settings
import io.github.the_brotherhood_of_scu.bugaoshan.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class AppConfigViewModel(private val settings: Settings) : ViewModel() {
    private val _themeColor = MutableStateFlow(settings.getLong(KEY_THEME_COLOR, 0xFF2196F3))
    val themeColor: StateFlow<Long> = _themeColor.asStateFlow()

    private val _locale = MutableStateFlow(settings.getString(KEY_LOCALE, "zh"))
    val locale: StateFlow<String> = _locale.asStateFlow()

    private val _cardSizeAnimationDuration = MutableStateFlow(settings.getInt(KEY_CARD_SIZE_ANIMATION_DURATION, 300))
    val cardSizeAnimationDuration: StateFlow<Int> = _cardSizeAnimationDuration.asStateFlow()

    private val _colorOpacity = MutableStateFlow(settings.getFloat(KEY_COLOR_OPACITY, 0.25f))
    val colorOpacity: StateFlow<Float> = _colorOpacity.asStateFlow()

    private val _fontSize = MutableStateFlow(settings.getFloat(KEY_COURSE_CARD_FONT_SIZE, 12f))
    val fontSize: StateFlow<Float> = _fontSize.asStateFlow()

    private val _showCourseGrid = MutableStateFlow(settings.getBoolean(KEY_COURSE_SHOW_COURSE_GRID, true))
    val showCourseGrid: StateFlow<Boolean> = _showCourseGrid.asStateFlow()

    private val _courseRowHeight = MutableStateFlow(settings.getInt(KEY_COURSE_ROW_HEIGHT, 120))
    val courseRowHeight: StateFlow<Int> = _courseRowHeight.asStateFlow()

    private val _showTeacher = MutableStateFlow(settings.getBoolean(KEY_COURSE_SHOW_TEACHER_NAME, true))
    val showTeacher: StateFlow<Boolean> = _showTeacher.asStateFlow()

    private val _showLocation = MutableStateFlow(settings.getBoolean(KEY_COURSE_SHOW_LOCATION, true))
    val showLocation: StateFlow<Boolean> = _showLocation.asStateFlow()

    private val _showWeekend = MutableStateFlow(settings.getBoolean(KEY_COURSE_SHOW_WEEKEND, false))
    val showWeekend: StateFlow<Boolean> = _showWeekend.asStateFlow()

    private val _showNonCurrentWeekCourses = MutableStateFlow(settings.getBoolean(KEY_COURSE_SHOW_NON_CURRENT_WEEK_COURSES, true))
    val showNonCurrentWeekCourses: StateFlow<Boolean> = _showNonCurrentWeekCourses.asStateFlow()

    fun updateThemeColor(color: Long) {
        settings.putLong(KEY_THEME_COLOR, color)
        _themeColor.value = color
    }

    fun updateLocale(locale: String) {
        settings.putString(KEY_LOCALE, locale)
        _locale.value = locale
    }

    fun updateCardSizeAnimationDuration(duration: Int) {
        settings.putInt(KEY_CARD_SIZE_ANIMATION_DURATION, duration)
        _cardSizeAnimationDuration.value = duration
    }

    fun updateColorOpacity(opacity: Float) {
        settings.putFloat(KEY_COLOR_OPACITY, opacity)
        _colorOpacity.value = opacity
    }

    fun updateFontSize(size: Float) {
        settings.putFloat(KEY_COURSE_CARD_FONT_SIZE, size)
        _fontSize.value = size
    }

    fun updateShowCourseGrid(show: Boolean) {
        settings.putBoolean(KEY_COURSE_SHOW_COURSE_GRID, show)
        _showCourseGrid.value = show
    }

    fun updateCourseRowHeight(height: Int) {
        settings.putInt(KEY_COURSE_ROW_HEIGHT, height)
        _courseRowHeight.value = height
    }

    fun updateShowTeacher(show: Boolean) {
        settings.putBoolean(KEY_COURSE_SHOW_TEACHER_NAME, show)
        _showTeacher.value = show
    }

    fun updateShowLocation(show: Boolean) {
        settings.putBoolean(KEY_COURSE_SHOW_LOCATION, show)
        _showLocation.value = show
    }

    fun updateShowWeekend(show: Boolean) {
        settings.putBoolean(KEY_COURSE_SHOW_WEEKEND, show)
        _showWeekend.value = show
    }

    fun updateShowNonCurrentWeekCourses(show: Boolean) {
        settings.putBoolean(KEY_COURSE_SHOW_NON_CURRENT_WEEK_COURSES, show)
        _showNonCurrentWeekCourses.value = show
    }

    fun resetToDefaults() {
        settings.remove(KEY_THEME_COLOR)
        settings.remove(KEY_COLOR_OPACITY)
        settings.remove(KEY_COURSE_CARD_FONT_SIZE)
        settings.remove(KEY_COURSE_SHOW_COURSE_GRID)
        settings.remove(KEY_COURSE_ROW_HEIGHT)
        settings.remove(KEY_COURSE_SHOW_TEACHER_NAME)
        settings.remove(KEY_COURSE_SHOW_LOCATION)
        settings.remove(KEY_COURSE_SHOW_WEEKEND)
        settings.remove(KEY_COURSE_SHOW_NON_CURRENT_WEEK_COURSES)

        _themeColor.value = 0xFF2196F3
        _colorOpacity.value = 0.25f
        _fontSize.value = 12f
        _showCourseGrid.value = true
        _courseRowHeight.value = 120
        _showTeacher.value = true
        _showLocation.value = true
        _showWeekend.value = false
        _showNonCurrentWeekCourses.value = true
    }
}
