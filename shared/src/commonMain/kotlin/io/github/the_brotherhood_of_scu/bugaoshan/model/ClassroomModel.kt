package io.github.the_brotherhood_of_scu.bugaoshan.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

@Serializable
data class ClassroomCampus(
    val number: String,
    val name: String,
)

@Serializable
data class ClassroomBuilding(
    val number: String,
    val name: String,
)

@Serializable
data class ClassroomType(
    val number: String,
    val name: String,
)

@Serializable
data class ClassroomInfo(
    val name: String,
    val capacity: Int,
    val status: String,
    val periods: List<ClassroomPeriod>,
    val canBorrow: Boolean,
    val remark: String,
)

@Serializable
data class ClassroomPeriod(
    val period: String,
    val status: String,
    val courseName: String?,
    val teacher: String?,
)

@Serializable
data class ClassroomQueryResult(
    val classrooms: List<ClassroomInfo>,
    val total: Int,
) {
    companion object {
        fun fromJsonObject(element: JsonElement): ClassroomQueryResult {
            val obj = element.jsonObject
            val data = obj["data"]?.jsonObject
            val rows = data?.get("rows")?.jsonArray ?: emptyList()
            val classrooms = rows.map { row ->
                val rowObj = row.jsonObject
                val periods = rowObj["periods"]?.jsonArray?.map { p ->
                    val pObj = p.jsonObject
                    ClassroomPeriod(
                        period = pObj["period"]?.jsonPrimitive?.content ?: "",
                        status = pObj["status"]?.jsonPrimitive?.content ?: "",
                        courseName = pObj["courseName"]?.jsonPrimitive?.content,
                        teacher = pObj["teacher"]?.jsonPrimitive?.content,
                    )
                } ?: emptyList()

                ClassroomInfo(
                    name = rowObj["name"]?.jsonPrimitive?.content ?: "",
                    capacity = rowObj["capacity"]?.jsonPrimitive?.int ?: 0,
                    status = rowObj["status"]?.jsonPrimitive?.content ?: "",
                    periods = periods,
                    canBorrow = rowObj["canBorrow"]?.jsonPrimitive?.booleanOrNull ?: false,
                    remark = rowObj["remark"]?.jsonPrimitive?.content ?: "",
                )
            }

            return ClassroomQueryResult(
                classrooms = classrooms,
                total = data?.get("total")?.jsonPrimitive?.int ?: 0,
            )
        }
    }
}
