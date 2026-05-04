package io.github.the_brotherhood_of_scu.bugaoshan.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.github.the_brotherhood_of_scu.bugaoshan.api.*
import io.github.the_brotherhood_of_scu.bugaoshan.model.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class CampusViewModel(
    private val classroomApi: ClassroomApiService,
    private val gradeApi: GradeApiService,
    private val balanceApi: BalanceApiService,
    private val networkDeviceApi: NetworkDeviceApiService,
    private val trainingApi: TrainingProgramApiService,
) : ViewModel() {

    // ==================== Classroom ====================
    private val _classroomLoading = MutableStateFlow(false)
    val classroomLoading: StateFlow<Boolean> = _classroomLoading.asStateFlow()

    private val _classrooms = MutableStateFlow<List<ClassroomInfo>>(emptyList())
    val classrooms: StateFlow<List<ClassroomInfo>> = _classrooms.asStateFlow()

    private val _campuses = MutableStateFlow<List<ClassroomCampus>>(emptyList())
    val campuses: StateFlow<List<ClassroomCampus>> = _campuses.asStateFlow()

    private val _buildings = MutableStateFlow<List<ClassroomBuilding>>(emptyList())
    val buildings: StateFlow<List<ClassroomBuilding>> = _buildings.asStateFlow()

    private val _classroomError = MutableStateFlow<String?>(null)
    val classroomError: StateFlow<String?> = _classroomError.asStateFlow()

    fun queryClassrooms(accessToken: String, campus: String, building: String, dayOfWeek: Int, section: Int) {
        _classroomLoading.value = true
        _classroomError.value = null
        viewModelScope.launch {
            try {
                val result = classroomApi.queryClassrooms(campus, building, dayOfWeek, section, accessToken)
                _classrooms.value = result.classrooms
            } catch (e: Exception) {
                _classroomError.value = "查询失败: ${e.message}"
            } finally {
                _classroomLoading.value = false
            }
        }
    }

    fun loadCampuses(accessToken: String) {
        viewModelScope.launch {
            _campuses.value = classroomApi.getCampuses(accessToken)
        }
    }

    fun loadBuildings(accessToken: String, campus: String) {
        viewModelScope.launch {
            _buildings.value = classroomApi.getBuildings(campus, accessToken)
        }
    }

    fun getFreeClassrooms(accessToken: String, campus: String, building: String, dayOfWeek: Int, section: Int, onResult: (List<ClassroomInfo>) -> Unit) {
        viewModelScope.launch {
            val result = classroomApi.getFreeClassrooms(campus, building, dayOfWeek, section, accessToken)
            onResult(result)
        }
    }

    // ==================== Grades ====================
    private val _gradeLoading = MutableStateFlow(false)
    val gradeLoading: StateFlow<Boolean> = _gradeLoading.asStateFlow()

    private val _grades = MutableStateFlow<SchemeScore?>(null)
    val grades: StateFlow<SchemeScore?> = _grades.asStateFlow()

    private val _gradeSemesters = MutableStateFlow<List<String>>(emptyList())
    val gradeSemesters: StateFlow<List<String>> = _gradeSemesters.asStateFlow()

    private val _gradeError = MutableStateFlow<String?>(null)
    val gradeError: StateFlow<String?> = _gradeError.asStateFlow()

    fun loadGrades(accessToken: String, semester: String? = null) {
        _gradeLoading.value = true
        _gradeError.value = null
        viewModelScope.launch {
            try {
                _grades.value = gradeApi.fetchGrades(accessToken, semester)
            } catch (e: Exception) {
                _gradeError.value = "查询失败: ${e.message}"
            } finally {
                _gradeLoading.value = false
            }
        }
    }

    fun loadSemesters(accessToken: String) {
        viewModelScope.launch {
            _gradeSemesters.value = gradeApi.fetchSemesters(accessToken)
        }
    }

    // ==================== Balance ====================
    private val _balanceLoading = MutableStateFlow(false)
    val balanceLoading: StateFlow<Boolean> = _balanceLoading.asStateFlow()

    private val _balanceResult = MutableStateFlow<BalanceResult?>(null)
    val balanceResult: StateFlow<BalanceResult?> = _balanceResult.asStateFlow()

    private val _dormitories = MutableStateFlow<List<Dormitory>>(emptyList())
    val dormitories: StateFlow<List<Dormitory>> = _dormitories.asStateFlow()

    fun queryBalance(accessToken: String, buildingId: String, roomId: String) {
        _balanceLoading.value = true
        viewModelScope.launch {
            try {
                _balanceResult.value = balanceApi.queryBalance(accessToken, buildingId, roomId)
            } catch (e: Exception) {
                _balanceResult.value = BalanceResult.Error("查询失败: ${e.message}")
            } finally {
                _balanceLoading.value = false
            }
        }
    }

    fun loadDormitories(accessToken: String) {
        viewModelScope.launch {
            _dormitories.value = balanceApi.getDormitories(accessToken)
        }
    }

    // ==================== Network Devices ====================
    private val _networkLoading = MutableStateFlow(false)
    val networkLoading: StateFlow<Boolean> = _networkLoading.asStateFlow()

    private val _networkResult = MutableStateFlow<NetworkDeviceResult?>(null)
    val networkResult: StateFlow<NetworkDeviceResult?> = _networkResult.asStateFlow()

    fun loadOnlineDevices(accessToken: String) {
        _networkLoading.value = true
        viewModelScope.launch {
            try {
                _networkResult.value = networkDeviceApi.getOnlineDevices(accessToken)
            } catch (e: Exception) {
                _networkResult.value = NetworkDeviceResult.Error("查询失败: ${e.message}")
            } finally {
                _networkLoading.value = false
            }
        }
    }

    fun disconnectDevice(accessToken: String, macAddress: String, onResult: (Boolean) -> Unit) {
        viewModelScope.launch {
            val success = networkDeviceApi.disconnectDevice(accessToken, macAddress)
            onResult(success)
            if (success) {
                loadOnlineDevices(accessToken)
            }
        }
    }

    // ==================== Training Program ====================
    private val _trainingLoading = MutableStateFlow(false)
    val trainingLoading: StateFlow<Boolean> = _trainingLoading.asStateFlow()

    private val _trainingResult = MutableStateFlow<TrainingProgramResult?>(null)
    val trainingResult: StateFlow<TrainingProgramResult?> = _trainingResult.asStateFlow()

    private val _colleges = MutableStateFlow<List<CollegeInfo>>(emptyList())
    val colleges: StateFlow<List<CollegeInfo>> = _colleges.asStateFlow()

    fun loadTrainingProgram(accessToken: String, college: String? = null, grade: String? = null) {
        _trainingLoading.value = true
        viewModelScope.launch {
            try {
                _trainingResult.value = trainingApi.getTrainingProgram(accessToken, college, grade)
            } catch (e: Exception) {
                _trainingResult.value = TrainingProgramResult.Error("查询失败: ${e.message}")
            } finally {
                _trainingLoading.value = false
            }
        }
    }

    fun loadColleges(accessToken: String) {
        viewModelScope.launch {
            _colleges.value = trainingApi.getColleges(accessToken)
        }
    }
}
