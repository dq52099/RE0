import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:re0/core/app_brand.dart';
import 'package:re0/core/compact_dropdown_field.dart';
import 'package:re0/features/home/home_screen.dart';

import '../test/admin_management_test.dart' as admin;
import '../test/desktop_dropdown_regression_test.dart' as evidence;
import '../test/frontend_management_test.dart' as frontend;

// Exercise the production widgets in a real Windows process. Only gateway
// responses and local preferences are fixtures; no real generation is submitted.
Future<void> resizeNativeWindow(
    WidgetTester tester, int width, int height) async {
  final script = r'''
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class RE0TestWindow {
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h,int x,int y,int w,int hgt,bool repaint);
}
'@
$re0Handle = (Get-Process -Id __PROCESS__).MainWindowHandle
if ($re0Handle -eq 0) { throw 'Native window missing' }
$re0Outer = New-Object RE0TestWindow+Rect
$re0Client = New-Object RE0TestWindow+Rect
[RE0TestWindow]::GetWindowRect($re0Handle,[ref]$re0Outer) | Out-Null
[RE0TestWindow]::GetClientRect($re0Handle,[ref]$re0Client) | Out-Null
$re0ExtraWidth = $re0Outer.R - $re0Outer.L - $re0Client.R
$re0ExtraHeight = $re0Outer.B - $re0Outer.T - $re0Client.B
[RE0TestWindow]::MoveWindow($re0Handle,10,10,__WIDTH__+$re0ExtraWidth,__HEIGHT__+$re0ExtraHeight,$true) | Out-Null
'''
      .replaceAll('__PROCESS__', '$pid')
      .replaceAll('__WIDTH__', '$width')
      .replaceAll('__HEIGHT__', '$height');
  final result = await tester.runAsync(() => Process.run(
      'powershell', ['-NoProfile', '-NonInteractive', '-Command', script]));
  expect(result!.exitCode, 0, reason: result.stderr.toString());
  await tester.pumpAndSettle();
}

Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is CompactDropdownField && widget.label == label);

Future<void> checkMenu(
    WidgetTester tester, GlobalKey boundary, String label, String name) async {
  await tester.ensureVisible(field(label));
  await tester.pumpAndSettle();
  await tester.tap(field(label));
  await tester.pumpAndSettle();
  expect(find.byType(MenuItemButton), findsWidgets);
  final item = find.byType(MenuItemButton).first;
  final surface = find
      .ancestor(
          of: item,
          matching: find.byWidgetPredicate((widget) =>
              widget is Material &&
              widget.elevation == 4 &&
              widget.type == MaterialType.canvas))
      .first;
  final rect = tester.getRect(surface);
  final media = MediaQuery.of(tester.element(field(label)));
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(media.size.width));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(media.size.height));
  await evidence.capture(tester, boundary, name);
  final last = find.byType(MenuItemButton).last;
  await tester.ensureVisible(last);
  await tester.pumpAndSettle();
  await tester.tap(last);
  await tester.pumpAndSettle();
  expect(find.byType(MenuItemButton), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(evidence.loadMenuFonts);
  testWidgets('Windows native generation and management menus', (tester) async {
    expect(Platform.isWindows, isTrue);
    final metrics = <Map<String, dynamic>>[];
    for (final width in [1000, 1360]) {
      await resizeNativeWindow(tester, width, 820);
      await frontend.mount(
          tester, const HomeScreen(), frontend.FrontendGateway(),
          configureView: false);
      await tester.tap(find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(AppBrands.re0.generateTabLabel)));
      await tester.pumpAndSettle();
      final media = MediaQuery.of(tester.element(field('画面比例')));
      metrics.add({
        'client_width': media.size.width,
        'client_height': media.size.height,
        'dpi_scale': media.devicePixelRatio
      });
      for (final label in ['张数', '分辨率', '画面比例']) {
        await checkMenu(
            tester, frontend.boundary, label, 'native-$width-$label');
      }
      await tester.ensureVisible(find.text('高级设置'));
      await tester.tap(find.text('高级设置'));
      await tester.pumpAndSettle();
      for (final label in ['质量', '背景', '文件格式']) {
        await checkMenu(
            tester, frontend.boundary, label, 'native-$width-$label');
      }
    }
    final gateway = admin.ManagementGateway();
    await admin.mountAdmin(tester, gateway,
        view: 'users',
        configureView: false,
        theme: AppBrands.re0.theme.copyWith(
            textTheme: AppBrands.re0.theme.textTheme
                .apply(fontFamily: 'AdminEvidence')));
    await tester.tap(find.byTooltip('编辑用户').first);
    await tester.pumpAndSettle();
    for (final label in ['角色', '用户组']) {
      await checkMenu(tester, admin.boundaryKey, label, 'native-admin-$label');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    final root = Platform.environment['RE0_MENU_EVIDENCE'] ??
        'evidence/screenshots/menu-fixes-20261007';
    await tester.runAsync(() async {
      final file = File('$root/native-windows/runtime.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'platform': Platform.operatingSystem,
        'real_native_window': true,
        'gateway': 'fixtures',
        'windows': metrics,
        'passed': true
      }));
    });
  });
}
