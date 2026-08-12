# ADR-0005：撤销余额历史记录的账号隔离

- 状态：已接受并实施
- 决策日期：2026-08-12

## 背景

PR #198（`refactor/balance-provider-state`，merge commit `e354cec`）在把余额查询远端状态收敛到 `BalanceQueryProvider` 的同时，引入了**账号维度的数据隔离**：

1. 身份状态机：Provider 增加 `setUserIdentity` / `activateForPrincipal` / `clear()` / `confirmedUserIdentity`，由 injector 在登录、切换账号和登出时驱动。
2. 历史记录按账号隔离：房间标识 `roomKey` 增加 `balance-v2:$identity:` 前缀，同一房间在不同账号下是不同 key，各自采样、各自存历史。
3. 绑定按账号分区存储：SharedPreferences key 变为 `balance_query_binding_<identity>` / `balance_query_current_room_<identity>`，并配套旧数据的按账号迁移逻辑。
4. 登出清理：登出时清空 Provider 内存状态。


## 决策

**撤销余额查询的账号隔离，余额数据按房间维度全局共享：**

1. `roomKey` 只由房间属性构成（`schoolCode_regCode_unitCode_roomNo`），不含账号信息；历史记录跨账号复用。
2. 绑定与当前房间索引恢复全局持久化（`balance_query_binding` / `balance_query_current_room`），不做按账号分区和迁移。
3. 移除身份状态机（`setUserIdentity` / `activateForPrincipal` / `clear` / `confirmedUserIdentity` 及 generation 守卫），登出不再清空余额数据。
4. 保留 PR #198 的状态收敛架构：页面只读 Provider 快照并发出加载/刷新意图；保留多房间/多范围缓存（余额 30 分钟 TTL、趋势按范围）、并发请求合并（in-flight 复用）和"余额解析失败不写 0"的修复。

## 理由

1. **不是隐私数据**：宿舍电费/空调余额是房间维度的公共数据，同寝室成员看到的是同一房间、同一数值，隔离的隐私前提不成立。
2. **避免重复获取**：账号隔离使同寝室成员各自的 `roomKey` 不同，室友查询并采样过的历史记录无法复用，造成重复请求和重复采样。
3. **降低复杂度**：身份状态机、分区存储、数据迁移和登出清理钩子只为隔离服务；撤销后 Provider 不再感知登录账号，与成绩等隐私数据（按账号隔离）形成清晰对比。

## 兼容性

- 页面与 Provider 的公开 API 不变（`balanceStateFor` / `trendStateFor` / `ensureBalance` / `ensureTrend` 等），UI 层零改动。
- 其余 Provider（成绩等隐私数据）的账号隔离不受影响。

## 后果

正面影响：

- 同寝室账号共享历史记录与自动采样结果，避免重复获取。
- Provider 简化：无身份状态、无迁移、无登出清理分支。
- 登出/切换账号不会让余额查询页丢失已绑定房间。

代价与约束：

- 余额数据不能再按账号扩展私有化；未来若出现账号维度的余额数据，需重新设计存储 key。
- 多账号共用同一份绑定列表：任何账号都能看到（非隐私的）房间绑定集合。
