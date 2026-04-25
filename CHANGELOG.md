# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.1] - 2025-04-24

### Added

- 成绩单功能：支持查看和导出学时
- 课程表非本周显示功能开关：支持开关显示非本周课程
- 余额查询功能：支持查询照明和空调余额

### Changed

- 二课活动详情页时间显示改为两行布局
- 更新服务重构：将 GitHub Release 方法移至 UpdateService

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

## [0.5.6] - 2024-12-20

### Changed

- 成绩页面 TabView 改为 BottomNavigationBar，导航更直观
- 第二课堂页面结构重构，优化导航和状态管理
- 发布工作流重构
- 训练计划列表底部增加间距
- 非移动平台隐藏刷新按钮

## [0.5.5] - 2024-12-06

### Fixed

- 登出时清除 ScuAuthProvider 状态

### Changed

- 移除 iOS 和 Windows 构建步骤（临时）
