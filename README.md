# RE0

从零开始的异世界生图。

## 功能

- 默认网关：`https://image.6688667.xyz`，打开 App 后只需要登录。
- 生图、改图、历史记录与原生系统管理页面共用网关 Cookie 会话。
- 生图/改图参数从网关能力接口读取，支持数量、尺寸、质量、背景和输出格式。
- 图片结果自动缓存，图片卡片右下角可下载到手机相册。
- 记忆回廊支持分页加载、下拉刷新和点击图片全屏预览。
- 生图页支持根据简单想法生成咒文，也支持选择图片反推咒文；点击咒文可查看和编辑完整内容。
- 反馈与许愿支持用户提交预置分类、查看状态和管理员回复，管理员可在系统管理里筛选、回复、按数量/间隔自动 AI 整理并导出反馈清单。
- 系统设置支持主用/备用上游 `base_url` 和 Key、当前线路、文本探活开关与探活间隔；后端每小时探活失败会自动切换主备并通知管理员。
- 系统设置支持 Claw163/Resend/SMTP 邮件通道；验证码和系统通知共用同一套主备发送策略。
- 系统管理提供数据备份页签，可查看本地、Google Drive、OpenList 主备备份状态和历史记录，并手动触发备份。
- 反馈、画廊、通知、历史、积分与系统管理统一使用本地时间展示，今天/昨天会直接显示。
- 画廊支持公开作品、点赞、收藏、下载、层级评论和回复，相关互动会进入用户通知。
- “我的”页面支持每日签到、通知、反馈、查看/清理图片缓存、检查更新、退出登录。
- 根据登录用户的角色、权限或菜单识别管理员，显示“系统管理”入口。
- 系统管理默认进入概览，包含用户、邀请码、反馈、反馈 AI、用户组、角色和密钥入口；需求清单合并在反馈 AI 下方，画廊不再作为系统管理页签展示。
- 支持在“我的 -> 主题风格”中切换 `RE0`、`原神`、`星穹铁道`、`鸣潮`、`绝区零`、`烟云十六声` 与 `希卡之石` 主题。
- App 内“检查更新”默认从 GitHub Release 获取 APK 并拉起系统安装器；开启强制更新时，启动会先走网关的移动端更新接口并阻断进入。

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
- App 内手动更新源配置在 `lib/core/providers.dart`，默认读取 `dq52099/RE0` 的 latest release；启动强制更新读取默认网关的 `/api/mobile/apps/re0/update`。
- 强制更新发布时请同时同步 `RE0-<tag>.apk` 和 `manifest.json` 到网关的 `apks/re0/` 目录，否则启动拦截会拿不到新包。
- Release APK 使用 GitHub Secrets 中的固定 release keystore 签名。需要配置 `RE0_KEYSTORE_BASE64`、`RE0_KEYSTORE_PASSWORD`、`RE0_KEY_ALIAS`、`RE0_KEY_PASSWORD`。
- 当前发布版本号为 `1.2.21+10221`，后续直接按常规版本号递增即可。

## 构建

```bash
flutter pub get
dart run flutter_launcher_icons:main
flutter build apk --release
```
