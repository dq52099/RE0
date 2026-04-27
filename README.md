# RE0

从零开始的异世界生图。

## 功能

- 默认网关：`https://image.6688667.xyz`，打开 App 后只需要登录。
- 生图、改图、历史记录与原生系统管理页面共用网关 Cookie 会话。
- 生图/改图参数从网关能力接口读取，支持数量、尺寸、质量、背景和输出格式。
- 图片结果自动缓存，图片卡片右下角可下载到手机相册。
- 记忆回廊支持分页加载、下拉刷新和点击图片全屏预览。
- “我的”页面支持查看/清理图片缓存、检查更新、退出登录。
- 根据登录用户的角色、权限或菜单识别管理员，显示“系统管理”入口。
- 支持在“我的 -> 主题风格”中切换 `RE0`、`原神`、`星穹铁道`、`鸣潮`、`绝区零`、`烟云十六声` 与 `希卡之石` 主题。
- 后续更新从 GitHub Release 获取 APK 并拉起系统安装器。

## 发布

GitHub Actions 位于 `.github/workflows/build-apk.yml`。

- 普通 `main` 分支构建会上传 `RE0-apk` artifact。
- 推送 `v*` tag 时会生成 `RE0-<tag>.apk` 并同步到 GitHub Release。
- App 内更新源配置在 `lib/core/providers.dart`，默认读取 `dq52099/RE0` 的 latest release。

## 构建

```bash
flutter pub get
dart run flutter_launcher_icons:main
flutter build apk --release
```
