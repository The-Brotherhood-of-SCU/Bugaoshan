# ADR-0007：本科生 / 研究生身份为全局展示开关

- 状态：已接受并实施
- 决策日期：2026-09-21
- 实施提交：见本 ADR 对应特性分支 `feat/student-mode-switch`

## 背景

本科教务（zhjw）与研教务（gsapp/ehall）是两套独立子系统。此前功能入口不做区分：
研究生打开「成绩统计」「考试安排」等本科教务页面，只会收到
`undergradOnly` 会话错误与指引文案（ADR 外的 PR #335/#337 机制）；而课表导入
弹窗同时列出本科三个入口与研究生入口，本科生与研究生都要在无关入口中翻找。

用户身份（学号）虽然可从登录态推断，但存在一人多身份、延迟定案等边界；
且用户希望主动决定「把 App 当本科生版还是研究生版用」。

## 决策

新增全局枚举 `StudentType { undergraduate, graduate }`（`lib/models/student_type.dart`），
由用户手动选择，持久化在 `AppConfigProvider.studentType`
（SharedPreferences key `studentType`，int 索引，默认 `undergraduate`）。
选择入口有两个：首次引导页（欢迎页之后的独立步骤）与
「软件设置 → 通用 → 学生类型」页，随时可切换、立即生效。

展示过滤规则：

1. `CampusItemConfig` 新增可选 `audience` 字段；null 表示通用（两种身份都展示）。
   仅本科教务专属项（grades / plan_completion / exam_plan / train_program /
   class_schedule_inquiry / course_curriculum / classroom）标 `undergraduate`，
   研究生专属项（graduate_schedule_import，后续研究生功能同）标 `graduate`。
2. 过滤由纯函数完成（`campusItemVisibleForStudentType` /
   `campusSectionsForStudentType` / `allCampusItemsForStudentType`），带单测；
   校园页（含搜索范围）、首页 dock 渲染、dock 自定义页三处消费同一套过滤。
3. 课表导入弹窗：分享粘贴（应用自有导出格式，与身份无关）恒展示；
   本科生模式展示教务处两个入口，研究生模式展示研究生课表导入。
   引导页登录步骤的导入按钮按同样规则分流。
4. **过滤是临时的、非破坏性的**：切换身份只隐藏入口，不改动
   `visibleDockIds` 等已保存配置（dock 自定义页的拖拽按 id 映射回完整列表），
   切回身份后一切恢复。

身份不用于鉴权或数据域隔离：`undergradOnly` 错误引导机制保留，
作为「选错身份 / 依赖账号的兜底提示」。

## 后果

正面影响：

- 两种用户看到的功能列表与导入入口与自身匹配，减少无效入口与误操作。
- 后续研究生功能（成绩 / 培养方案等）落地时只需新增带 `audience` 标记的
  `CampusItemConfig`，展示侧零改动。
- 切换可逆、不丢配置；清除全部数据（`clearAll`）后回落本科生默认。

代价与约束：

- 身份是手动选择，可能选错；依赖 `undergradOnly` 错误文案兜底引导。
- 新增的全局开关让「通用 vs 专属」成为每个校园功能项的必答字段，
  忘记打标的功能项会以通用身份出现在两种模式下（宁漏勿隐的默认）。

## 修订（2026-09-21，研究生条目不单设分区）

既然身份由全局开关决定，就不必再为研究生单设一个「研究生」分区：
研究生条目按「对应的本科功能」就地并入常规分区——研究生成绩紧邻成绩统计、
培养进度紧邻方案修读情况（学业区），课表导入紧邻班级课表/课程课表
（实用功能区）。显隐仍由 `audience` 过滤完成，过滤纯函数与三处消费方
不变；过滤后为空的分区整体隐藏的规则保留（现无分区再触发该路径）。
