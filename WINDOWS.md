# RE0 Windows 桌面版

支持 Windows 10 / 11 x64；连接同一 RE0 服务，账户、额度、图片记录和后台配置与 APK、网页共用。

桌面端包括宽屏创作工作台、可缩放窗口、主题导航、按账号保存的提示词草稿、鼠标与键盘图片预览、系统文件选择器与另存为、可拖动缩放的头像裁剪。减少动画设置沿用系统偏好。快捷键：Alt + 1…5 切页，Ctrl + Enter 提交当前创作；预览中 ← / → 切图、+ / − 缩放、0 适应窗口、Esc 返回。

## 构建与安装

Windows 构建机需 Flutter 3.41.9、Visual Studio 2022 的“使用 C++ 的桌面开发”工作负载、Windows SDK 与 Inno Setup 6。在仓库根目录运行：

```powershell
./scripts/build-windows.ps1
./scripts/smoke-windows.ps1
```

输出位于 `build/release/`：每用户安装的 `*-windows-x64-setup.exe`、免安装压缩包、带 SHA-256 的 `manifest.json`。无需管理员权限，运行库随程序分发。卸载不删除账户配置和个人图片。

GitHub Actions 的 `Build Windows` 工作流使用 `windows-latest` 构建、运行测试，实际安装并启动程序验证窗口响应，然后卸载。安装包和验证证据通过 Actions artifact 交付，不自动发布 GitHub Release。

## 独立更新

Windows 从 `https://work.6688667.xyz/boxying-desktop/manifest.json` 检查更新。只接受 `windows-x64`、同目录 HTTPS `.exe` 和有效 SHA-256；下载后校验通过才启动安装器。Android 的强制升级配置不会拦截 Windows。将经过验证的产物放入该目录，再原子替换 manifest 即可发布。
