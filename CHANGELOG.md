# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

**注意：本次更新有非兼容性变更，请把旧版本卸载后安装新版本，不建议覆盖安装。**

### Added

### Changed

- 修改课表储存方式，从 SharedPreferences 到 sqlite 数据库

### Fixed

- 修复修改课表背景图片后，课表背景图片不刷新的问题
- 修复软件清除全部数据后，课表数据和账号密码数据不被删除的问题

## [0.7.0] - 2026-04-29

### Added

- 二课成绩单功能：支持查看和导出学时
- 课程表非本周显示功能开关：支持开关显示非本周课程
- 余额查询功能：支持查询电费和空调余额
- 课表导出功能：添加将课表导出为标准日历文件（iCalendar）功能
- 添加课表背景图片功能：支持自定义课表背景图片

### Changed

- 二课活动详情页时间显示改为两行布局
- 更新服务重构：将 GitHub Release 方法移至 UpdateService
- 版本更新：添加app内版本更新功能
- 优化课程卡片显示，防止卡片背景和字体颜色相近导致看不清
- 优化第二课堂请求失败提示，晚上0点到6点提示使用校园网访问
- 课表默认周数由16调整为20周
- 优化成绩页面刷新失败的逻辑，显示缓存数据而非清空

## [0.6.0] - 2025-04-23

### Added

- 登录失败错误提示本地化及友好错误处理
- OCR 验证码自动识别（TensorFlow Lite 方案）
- HarmonyOS 平台检测支持
- Linux 平台支持（桌面端）
- Windows 平台支持（桌面端）
- 安全存储方案替换 SharedPreferences 存储 Token
- 英文应用名称支持
- 课程表当前周设置功能

### Changed

- APK 构建改为按 ABI 分割打包，减小下载体积
- 应用包名改为小写格式
- 目录结构重构调整
- 移除 ONNX Runtime OCR，改用 TensorFlow Lite
- OCR 性能优化：Session 创建优化与资源清理

### Fixed

- OCR 服务初始化失败时优雅处理
- 登录密码安全存储问题
- 数据库文件存放位置问题

## [0.5.6] - 2026-04-21

### Changed

- 成绩页面 TabView 改为 BottomNavigationBar，导航更直观
- 第二课堂页面结构重构，优化导航和状态管理
- 发布工作流重构
- 训练计划列表底部增加间距
- 非移动平台隐藏刷新按钮
