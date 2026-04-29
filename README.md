# RE0

从零开始的异世界生图。

## 功能

- 默认网关：`https://image.6688667.xyz`，打开 App 后只需要登录。
- 生图、改图、历史记录与原生系统管理页面共用网关 Cookie 会话。
- 生图/改图参数从网关能力接口读取，支持数量、尺寸、质量、背景和输出格式。
- 图片结果自动缓存，图片卡片右下角可下载到手机相册。
- 记忆回廊支持分页加载、下拉刷新和点击图片全屏预览。
- 生图页支持根据简单想法生成咒文，也支持选择图片反推咒文；点击咒文可查看和编辑完整内容。
- 反馈与许愿支持用户提交、查看状态和管理员回复，管理员可在系统管理里筛选、回复、AI 整理和导出反馈清单。
- 画廊支持公开作品、点赞、收藏、下载、评论和回复，相关互动会进入用户通知。
- “我的”页面支持每日签到、通知、反馈、查看/清理图片缓存、检查更新、退出登录。
- 根据登录用户的角色、权限或菜单识别管理员，显示“系统管理”入口。
- 系统管理默认进入概览，包含用户、邀请码、反馈、画廊等数据入口。
- 支持在“我的 -> 主题风格”中切换 `RE0`、`原神`、`星穹铁道`、`鸣潮`、`绝区零`、`烟云十六声` 与 `希卡之石` 主题。
- 后续更新从 GitHub Release 获取 APK 并拉起系统安装器。

## 反馈清单

后续修 BUG 或做需求前，优先读取后端导出的已审批反馈清单：

```bash
cd /opt/migrate/code_workspace/boxying-image-gateway
ls -lt data/feedback_exports/
sed -n '1,220p' data/feedback_exports/latest_day.md
sed -n '1,260p' data/feedback_exports/latest_week.md
sed -n '1,320p' data/feedback_exports/latest_month.md
```

完成修复后，需要把对应反馈状态流转为 `resolved` 或 `closed`，并补管理员回复。

## 发布

GitHub Actions 位于 `.github/workflows/build-apk.yml`。

- 普通 `main` 分支构建会上传 `RE0-apk` artifact。
- 推送 `v*` tag 时会生成 `RE0-<tag>.apk` 并同步到 GitHub Release。
- App 内更新源配置在 `lib/core/providers.dart`，默认读取 `dq52099/RE0` 的 latest release。
- Release APK 使用 GitHub Secrets 中的固定 release keystore 签名。需要配置 `RE0_KEYSTORE_BASE64`、`RE0_KEYSTORE_PASSWORD`、`RE0_KEY_ALIAS`、`RE0_KEY_PASSWORD`。
- 当前底层 hotfix 按要求不改 `pubspec.yaml` 版本号；发布 tag 使用 `v1.1.35-hotfix2` 这类旧包也能识别的格式，避免已安装 `1.1.35` 的设备误判“已是最新版本”。

## 构建

```bash
flutter pub get
dart run flutter_launcher_icons:main
flutter build apk --release
```
