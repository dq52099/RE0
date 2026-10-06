# RE0

从零开始的异世界生图。

## 功能

- 默认网关：`https://image.6688667.xyz`，打开 App 后只需要登录。
- 生图、改图、历史记录与原生系统管理页面共用网关 Cookie 会话。
- 生图/改图参数从网关能力接口读取，支持数量、尺寸、质量、背景和输出格式。
- 图片结果自动缓存，图片卡片右下角可下载到手机相册。
- 生图/改图保持同步调用；断线后自动查询原请求的状态与结果，同一请求重试不重复生成或扣费。已提交的未确认请求按账号和服务器保留，重新打开后继续找回。
- 记忆回廊支持分页加载、下拉刷新和点击图片全屏预览。
- 生图页支持根据简单想法生成咒文，也支持选择图片反推咒文；点击咒文可查看和编辑完整内容。
- 反馈与许愿支持用户提交预置分类、查看状态和管理员回复，管理员可在系统管理里筛选、回复、按数量/间隔自动 AI 整理并导出反馈清单。
- 系统设置分别配置主用、备用和一般模式的服务开关；主备各自保存地址、密钥和生图模型，异步任务、第二密钥等折叠到高级设置；APK 不再展示图片档位。定时图片检测仅在开关开启时执行。
- VIP 图片倍率保存后刷新前台价格，进入生图/改图页或回到前台也会读取最新倍率；输入时实时预览每张费用。
- 设置保存只提交本次修改，并核对服务器返回值；保存失败保留输入，回到前台、点击刷新或下拉页面时读取最新配置，运行状态展示服务器实际使用的站点与模型。
- 系统设置支持 Claw163/Resend/SMTP 邮件通道；验证码和系统通知共用同一套主备发送策略。
- 后台支持用户搜索、账号状态筛选和设置搜索，常用设置使用中文名称及单位；概览和编辑表单适配小屏、大字体和平板。
- 系统管理提供数据备份页签，可查看本地、Google Drive、OpenList 主备备份状态和历史记录，并手动触发备份；OpenList 的云端清理、保留时间和上传等待上限可独立配置。
- 反馈、画廊、通知、历史、积分与系统管理统一使用本地时间展示，今天/昨天会直接显示。
- 画廊支持公开作品、点赞、收藏、下载、层级评论和回复，相关互动会进入用户通知。
- “我的”页面支持每日签到、通知、反馈、查看/清理图片缓存、检查更新、退出登录。
- 根据登录用户的角色、权限或菜单识别管理员，显示“系统管理”入口。
- 系统管理默认进入概览，包含用户、邀请码、反馈、反馈 AI、用户组、角色和密钥入口；需求清单合并在反馈 AI 下方，画廊不再作为系统管理页签展示。
- 支持在“我的 -> 主题风格”中切换 `RE0`、`原神`、`星穹铁道`、`鸣潮`、`绝区零`、`烟云十六声` 与 `希卡之石` 主题。
- App 内“检查更新”和启动更新统一读取网关移动端更新接口并拉起系统安装器；保留服务器配置的强制更新策略。

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
- App 内更新配置在 `lib/core/providers.dart`，手动及启动更新读取默认网关的 `/api/mobile/apps/re0/update`；启动强制更新在网关未提供可用更新时尝试 GitHub Release。
- 强制更新发布时请同时同步 `RE0-<tag>.apk` 和 `manifest.json` 到网关的 `apks/re0/` 目录，否则启动拦截会拿不到新包。
- Release APK 使用 GitHub Secrets 中的固定 release keystore 签名。需要配置 `RE0_KEYSTORE_BASE64`、`RE0_KEYSTORE_PASSWORD`、`RE0_KEY_ALIAS`、`RE0_KEY_PASSWORD`。
- 当前工程版本为 `1.2.41+10241`，修复手机切页晃动、管理编辑标签遮挡及启停状态显示。Windows 已发布版本为 `1.2.40+10240`。各平台独立发布，后续版本号继续递增。

## 构建

```bash
flutter pub get
dart run flutter_launcher_icons:main
flutter build apk --release
```


## Windows 桌面版

- [下载安装版与免安装版](https://work.6688667.xyz/boxying-desktop/)，支持 Windows 10 / 11 x64。
- 与 Android 和网页使用同一服务与账号；宽屏创作工作区、窗口记忆、按账号保存草稿、多列画廊、图片缩放与另存为均已支持。
- 快捷键：`Alt + 1…5` 切页，`Ctrl + Enter` 提交当前创作，预览中使用方向键、`+` / `-`、`0` 和 `Esc`。
- Windows 通过独立 manifest 检查更新，下载后校验 SHA-256；Android 保持原网关更新通道。
- 构建和安装测试见 [WINDOWS.md](WINDOWS.md)，自动构建入口为 `.github/workflows/build-windows.yml`。
