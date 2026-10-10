package io.github.the_brotherhood_of_scu.bugaoshan.reminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * 单条提醒条目原生数据结构。
 */
data class ReminderItemData(
    val id: String,
    val kind: String,
    val fireAtMillis: Long,
    val title: String,
    val body: String,
    val collapseKey: String?,
) {
    /**
     * 稳定的系统通知 ID。使用正数哈希映射，确保相同 id 覆盖更新而非堆积。
     */
    val stableNotificationId: Int
        get() = (id.hashCode() and 0x7FFFFFFF)

    fun toJsonObject(): JSONObject = JSONObject().apply {
        put("id", id)
        put("kind", kind)
        put("fireAtMillis", fireAtMillis)
        put("title", title)
        put("body", body)
        put("collapseKey", collapseKey ?: "")
    }

    companion object {
        fun fromJsonObject(json: JSONObject): ReminderItemData? {
            val id = json.optString("id")
            val kind = json.optString("kind")
            val fireAtMillis = json.optLong("fireAtMillis", -1L)
            if (id.isEmpty() || fireAtMillis <= 0L) return null
            return ReminderItemData(
                id = id,
                kind = kind,
                fireAtMillis = fireAtMillis,
                title = json.optString("title"),
                body = json.optString("body"),
                collapseKey = json.optString("collapseKey").takeIf { it.isNotEmpty() },
            )
        }

        fun fromChannelMap(map: Map<String, Any?>): ReminderItemData? {
            val id = map["id"] as? String ?: return null
            val kind = map["kind"] as? String ?: return null
            val fireAtMillis = (map["fireAtMillis"] as? Number)?.toLong() ?: return null
            if (id.isEmpty() || fireAtMillis <= 0L) return null
            return ReminderItemData(
                id = id,
                kind = kind,
                fireAtMillis = fireAtMillis,
                title = (map["title"] as? String) ?: "",
                body = (map["body"] as? String) ?: "",
                collapseKey = (map["collapseKey"] as? String)?.takeIf { it.isNotEmpty() },
            )
        }
    }
}

/**
 * 完整计划原生数据结构。
 */
data class ReminderPlanData(
    val schema: Int,
    val planId: String,
    val generatedAtMillis: Long,
    val windowStartMillis: Long,
    val windowEndMillis: Long,
    val channel: String,
    val droppedCount: Int,
    val reminders: List<ReminderItemData>,
) {
    fun toJsonString(): String {
        val root = JSONObject()
        root.put("schema", schema)
        root.put("planId", planId)
        root.put("generatedAtMillis", generatedAtMillis)
        root.put("windowStartMillis", windowStartMillis)
        root.put("windowEndMillis", windowEndMillis)
        root.put("channel", channel)
        root.put("droppedCount", droppedCount)

        val array = JSONArray()
        for (item in reminders) {
            array.put(item.toJsonObject())
        }
        root.put("reminders", array)
        return root.toString()
    }

    companion object {
        fun fromJsonString(jsonStr: String): ReminderPlanData? {
            return try {
                val root = JSONObject(jsonStr)
                val schema = root.optInt("schema", -1)
                val remindersArray = root.optJSONArray("reminders") ?: JSONArray()
                val list = mutableListOf<ReminderItemData>()
                for (i in 0 until remindersArray.length()) {
                    val obj = remindersArray.optJSONObject(i) ?: continue
                    ReminderItemData.fromJsonObject(obj)?.let { list.add(it) }
                }
                ReminderPlanData(
                    schema = schema,
                    planId = root.optString("planId"),
                    generatedAtMillis = root.optLong("generatedAtMillis"),
                    windowStartMillis = root.optLong("windowStartMillis"),
                    windowEndMillis = root.optLong("windowEndMillis"),
                    channel = root.optString("channel", ReminderNotification.DEFAULT_CHANNEL_ID),
                    droppedCount = root.optInt("droppedCount", 0),
                    reminders = list,
                )
            } catch (e: Exception) {
                null
            }
        }

        fun fromChannelMap(payload: Map<String, Any?>): ReminderPlanData? {
            val schema = (payload["schema"] as? Number)?.toInt() ?: return null
            val planId = payload["planId"] as? String ?: ""
            val generatedAtMillis = (payload["generatedAtMillis"] as? Number)?.toLong() ?: 0L
            val windowStartMillis = (payload["windowStartMillis"] as? Number)?.toLong() ?: 0L
            val windowEndMillis = (payload["windowEndMillis"] as? Number)?.toLong() ?: 0L
            val channel = (payload["channel"] as? String) ?: ReminderNotification.DEFAULT_CHANNEL_ID
            val droppedCount = (payload["droppedCount"] as? Number)?.toInt() ?: 0

            // reminders 必须真的是数组。此前 `as? List<Map<String, Any?>> ?: emptyList()` 会把
            // 「reminders 不是数组」静默降级成空计划并回报成功——用户侧表现为提醒凭空消失且无报错。
            // 这里改为交由调用方返回 INVALID_ARGUMENT。
            val remindersRaw = payload["reminders"]
            if (remindersRaw != null && remindersRaw !is List<*>) return null
            val remindersList: List<*>? = remindersRaw

            val list = remindersList.orEmpty().mapNotNull { element ->
                // 泛型擦除使 `as? List<Map<...>>` 不做元素检查，逐项再转一次才安全。
                @Suppress("UNCHECKED_CAST")
                (element as? Map<String, Any?>)?.let { ReminderItemData.fromChannelMap(it) }
            }

            return ReminderPlanData(
                schema = schema,
                planId = planId,
                generatedAtMillis = generatedAtMillis,
                windowStartMillis = windowStartMillis,
                windowEndMillis = windowEndMillis,
                channel = channel,
                // 把原生侧丢弃的条目数也计入，避免该字段只反映 Dart 侧的丢弃。
                droppedCount = droppedCount + (remindersList?.size ?: 0) - list.size,
                reminders = list,
            )
        }
    }
}

/**
 * 本地提醒的排期引擎。
 *
 * 职责：
 * 1. 使用 [AlarmManager] 注册唤醒闹钟（RTC_WAKEUP）。
 * 2. 处理 Android 14+ 精确闹钟权限（SCHEDULE_EXACT_ALARM）不可用时的降级。
 * 3. 持久化计划到 [SharedPreferences]，用于跨重启/更新后重建以及未完成查询。
 * 4. 全量替换机制：同步新计划前撤销老计划所有的未触发闹钟。
 * 5. 合并策略：同一触发时刻的多条提醒合并为单一 AlarmManager 注册，
 *    并在 Receiver 端拉起全部到期条目，避免 Doze 模式限频导致互相挤占。
 */
object ReminderScheduler {

    private const val TAG = "ReminderScheduler"

    const val ACTION_REMINDER_ALARM =
        "io.github.the_brotherhood_of_scu.bugaoshan.action.REMINDER_ALARM"

    const val EXTRA_FIRE_AT_MILLIS = "fire_at_millis"

    private const val PREFS_NAME = "bugaoshan_reminder_storage"
    private const val KEY_PLAN_JSON = "plan_json"
    private const val KEY_TIMESTAMPS = "scheduled_timestamps"
    private const val KEY_DELIVERED_IDS = "delivered_ids"
    private const val KEY_IS_EXACT_DOWNGRADED = "is_exact_downgraded"

    /**
     * RequestCode 基数。取 "RE"（Reminder）的十六进制字面量，纯记忆点用；
     * 数值 0x52450000 = 1381073696。
     *
     * 实际 requestCode 落在 0x52450000..0x5245FFFF（基址 `or` 上时间戳低 16 位），
     * 与 WidgetAlarmManager 的 20250101 / 20250102（约 2.03e7，即 0x0134FDF5 附近）
     * 完全不重叠，避免误撤销。
     */
    private const val REQUEST_CODE_BASE = 0x52450000

    /**
     * 判断当前系统是否允许设置精确闹钟。
     * - Android 12 (API 31)+ 支持 canScheduleExactAlarms() 查询。
     * - Android 14 (API 34)+ 默认不再对常规应用授予 SCHEDULE_EXACT_ALARM。
     * - API < 31 默认支持。
     */
    fun canScheduleExactAlarms(context: Context): Boolean {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    /**
     * 查询上次排期是否发生了精确闹钟降级。
     */
    fun isExactDowngraded(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_IS_EXACT_DOWNGRADED, false)
    }

    /**
     * 全量替换排期计划。
     *
     * 1. 撤销本地已记录的上批闹钟；
     * 2. 过滤已过期时刻；
     * 3. 按时刻分组排期（单时刻单闹钟，降低 Doze 消耗并避免挤占）；
     * 4. 写入持久化存储。
     *
     * @return 排入未来的提醒**条目数**（含同一时刻被合并成单个闹钟的多条）。
     *         它不等于实际登记的闹钟数——后者请用 [getPendingCount]。
     */
    fun syncPlan(context: Context, planData: ReminderPlanData): Int {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: run {
                Log.e(TAG, "AlarmManager not available")
                return 0
            }

        // 1. 全量撤销上一批闹钟。
        //
        //    注意 cancelAllAlarms 只按 KEY_TIMESTAMPS 撤闹钟、**不清 prefs**（清空由公开的
        //    cancelAll() 负责），因此「撤旧 → 建新 → 落盘」这个窗口里进程被杀不会丢计划：
        //    持久化里仍是**旧**计划，reconstructSchedule 会按旧计划重建，Dart 侧下次启动
        //    重新 syncPlan 即自愈。这个顺序不可调换——若先落盘新计划再撤旧闹钟，
        //    「已落盘、未注册」这一中途崩溃就会丢掉全部闹钟且没有持久化兜底，反而更糟。
        cancelAllAlarms(context, alarmManager)

        val now = System.currentTimeMillis()
        val futureReminders = planData.reminders.filter { it.fireAtMillis > now }

        val canExact = canScheduleExactAlarms(context)
        if (!canExact) {
            Log.w(
                TAG,
                "SCHEDULE_EXACT_ALARM permission not granted. " +
                    "Downgrading to setAndAllowWhileIdle (alarms may drift up to ~10-15m in Doze).",
            )
        }

        // 2. 按时刻分组：同一时刻多条提醒共享一个 AlarmManager 闹钟，合并唤醒
        val groupedByTimestamp = futureReminders.groupBy { it.fireAtMillis }
        val scheduledTimestamps = mutableSetOf<String>()

        for ((fireAtMillis, items) in groupedByTimestamp) {
            val pendingIntent = createAlarmPendingIntent(context, fireAtMillis)
            try {
                if (canExact) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        fireAtMillis,
                        pendingIntent,
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        fireAtMillis,
                        pendingIntent,
                    )
                }
                scheduledTimestamps.add(fireAtMillis.toString())
                Log.d(
                    TAG,
                    "Alarm scheduled at $fireAtMillis (exact=$canExact) for ${items.size} reminder(s)",
                )
            } catch (e: SecurityException) {
                // 部分定制 ROM 或权限骤降时可能抛出，回退处理
                Log.e(TAG, "SecurityException while scheduling alarm, trying inexact fallback", e)
                try {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        fireAtMillis,
                        pendingIntent,
                    )
                    scheduledTimestamps.add(fireAtMillis.toString())
                } catch (e2: Exception) {
                    Log.e(TAG, "Fallback alarm scheduling also failed", e2)
                }
            }
        }

        // 3. 持久化存储。
        //
        //    已投递历史用「剪枝」而不是全量清空：全量清空会让 Receiver 的补发窗口
        //    （ReminderAlarmReceiver.MAX_STALE_TOLERANCE_MILLIS）把刚投递过的提醒再发一遍——
        //    用户看到横幅 + 震动 + 提示音重复一次；而完全不清空又会让「已从计划移除」或
        //    「早已超出补发窗口」的 id 无限堆积。剪枝规则：仍在本计划中、且触发时刻仍落在
        //    补发窗口内的 id 保留已投递标记，其余丢弃。
        val deliveredBefore = getDeliveredIds(context)
        val retainedDelivered = deliveredBefore.filterTo(mutableSetOf()) { id ->
            val item = planData.reminders.firstOrNull { it.id == id }
            item != null &&
                item.fireAtMillis > now - ReminderAlarmReceiver.MAX_STALE_TOLERANCE_MILLIS
        }
        val prunedCount = deliveredBefore.size - retainedDelivered.size

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_PLAN_JSON, planData.toJsonString())
            .putStringSet(KEY_TIMESTAMPS, scheduledTimestamps)
            .putStringSet(KEY_DELIVERED_IDS, retainedDelivered)
            .putBoolean(KEY_IS_EXACT_DOWNGRADED, !canExact)
            .apply()

        Log.i(
            TAG,
            "Plan synced: planId=${planData.planId}, " +
                "total=${planData.reminders.size}, " +
                "futureScheduled=${futureReminders.size}, " +
                "uniqueAlarms=${scheduledTimestamps.size}, " +
                "deliveredPruned=$prunedCount",
        )
        return futureReminders.size
    }

    /**
     * 取消全部已排期闹钟并清空持久化存储。
     *
     * 这里用 [SharedPreferences.Editor.commit] 而非 `apply()`：`apply()` 是异步落盘，
     * 若在落盘完成前进程被杀，磁盘上仍留着旧计划，开机后 [reconstructSchedule] 会按旧计划
     * 把用户刚刚取消的闹钟**全部复活**。本方法由用户主动触发、非热路径，同步写盘的代价可接受。
     * ([syncPlan] 留在主线程的热路径上，仍用 `apply()`——那里由 QueuedWork 在组件停止时兜底。)
     */
    fun cancelAll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (alarmManager != null) {
            cancelAllAlarms(context, alarmManager)
        }
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        Log.i(TAG, "All reminders cancelled and cleared from storage")
    }

    /**
     * 查询系统当前有效待触发的条数。
     *
     * 以 [KEY_TIMESTAMPS]——即**实际登记进 AlarmManager 的时刻集合**——为准，而不是计划条目数。
     * [syncPlan] 会把同一时刻的多条提醒**合并成一次闹钟注册**（其日志里的 `uniqueAlarms`
     * 就是这个数），所以「提醒条数」与「系统闹钟数」在设计上本就是两个不同的量；
     * 按条目计数会系统性高报——3 条同时刻提醒在系统里只有 1 个闹钟，接口却会返回 3。
     *
     * 语义：已登记且尚未到点的闹钟数。
     */
    fun getPendingCount(context: Context): Int {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        return prefs.getStringSet(KEY_TIMESTAMPS, emptySet())
            .orEmpty()
            .count { (it.toLongOrNull() ?: 0L) > now }
    }

    /**
     * 重建排期链路（开机、应用更新、系统改时间、换时区时由 Receiver 触发）。
     */
    fun reconstructSchedule(context: Context) {
        val plan = getStoredPlan(context) ?: run {
            Log.d(TAG, "No stored plan found for reconstruction")
            return
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return

        // 撤销旧闹钟以防残留
        cancelAllAlarms(context, alarmManager)

        val now = System.currentTimeMillis()
        val deliveredIds = getDeliveredIds(context)
        val futureReminders = plan.reminders.filter {
            it.fireAtMillis > now && !deliveredIds.contains(it.id)
        }

        if (futureReminders.isEmpty()) {
            Log.d(TAG, "No remaining future reminders to reconstruct")
            return
        }

        val canExact = canScheduleExactAlarms(context)
        val groupedByTimestamp = futureReminders.groupBy { it.fireAtMillis }
        val scheduledTimestamps = mutableSetOf<String>()

        for ((fireAtMillis, _) in groupedByTimestamp) {
            val pendingIntent = createAlarmPendingIntent(context, fireAtMillis)
            try {
                if (canExact) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        fireAtMillis,
                        pendingIntent,
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        fireAtMillis,
                        pendingIntent,
                    )
                }
                scheduledTimestamps.add(fireAtMillis.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Failed to re-schedule alarm at $fireAtMillis", e)
            }
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putStringSet(KEY_TIMESTAMPS, scheduledTimestamps)
            .putBoolean(KEY_IS_EXACT_DOWNGRADED, !canExact)
            .apply()

        Log.i(
            TAG,
            "Reconstruction completed: restored ${futureReminders.size} reminders " +
                "across ${scheduledTimestamps.size} alarms",
        )
    }

    /**
     * 读取当前持久化的计划。
     */
    fun getStoredPlan(context: Context): ReminderPlanData? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val jsonStr = prefs.getString(KEY_PLAN_JSON, null) ?: return null
        return ReminderPlanData.fromJsonString(jsonStr)
    }

    /**
     * 读取已投递的条目 ID。
     *
     * 返回 [Set.toSet] 的防御性拷贝：`getStringSet` 返回的是 SharedPreferences 内部持有的
     * 集合，调用方一次 add/remove 就会抛 `UnsupportedOperationException`。
     */
    fun getDeliveredIds(context: Context): Set<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getStringSet(KEY_DELIVERED_IDS, emptySet()).orEmpty().toSet()
    }

    /**
     * 标记条目已投递。
     */
    fun markDelivered(context: Context, ids: Collection<String>) {
        if (ids.isEmpty()) return
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val current = prefs.getStringSet(KEY_DELIVERED_IDS, emptySet())?.toMutableSet() ?: mutableSetOf()
        current.addAll(ids)
        prefs.edit().putStringSet(KEY_DELIVERED_IDS, current).apply()
    }

    private fun cancelAllAlarms(context: Context, alarmManager: AlarmManager) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val timestamps = prefs.getStringSet(KEY_TIMESTAMPS, emptySet()) ?: emptySet()

        for (tsStr in timestamps) {
            val ts = tsStr.toLongOrNull() ?: continue
            val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
                action = ACTION_REMINDER_ALARM
                data = Uri.parse("bugaoshan-reminder://alarm/$ts")
            }
            val requestCode = generateRequestCode(ts)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }
    }

    private fun createAlarmPendingIntent(context: Context, fireAtMillis: Long): PendingIntent {
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            action = ACTION_REMINDER_ALARM
            data = Uri.parse("bugaoshan-reminder://alarm/$fireAtMillis")
            putExtra(EXTRA_FIRE_AT_MILLIS, fireAtMillis)
        }
        val requestCode = generateRequestCode(fireAtMillis)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * 生成稳定唯一的 requestCode。
     * - 高 16 位为基准偏移量 [REQUEST_CODE_BASE]；
     * - 低 16 位为时刻哈希值；
     * 保证与其它组件 requestCode 互不冲突。
     */
    private fun generateRequestCode(fireAtMillis: Long): Int {
        return REQUEST_CODE_BASE or (fireAtMillis.hashCode() and 0xFFFF)
    }
}
