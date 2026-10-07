import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/app_brand.dart';
import 'package:re0/core/compact_dropdown_field.dart';
import 'package:re0/core/image_capabilities.dart';
import 'package:re0/features/home/home_screen.dart';

import 'frontend_management_test.dart' as fixtures;

Future<void> capture(
    WidgetTester tester, GlobalKey boundary, String name) async {
  final phase = Platform.environment['RE0_CAPTURE_MENUS'];
  if (phase == null) return;
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
        '${Platform.environment['RE0_MENU_EVIDENCE'] ?? 'evidence/screenshots/menu-fixes-20261007'}/$phase/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> loadMenuFonts() async {
  if (Platform.environment['RE0_CAPTURE_MENUS'] == null) return;
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '/home/ubuntu/flutter';
  final fonts = <String, String>{
    'FrontendEvidence': Platform.isWindows
        ? 'C:/Windows/Fonts/msyh.ttc'
        : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    'AdminEvidence': Platform.isWindows
        ? 'C:/Windows/Fonts/msyh.ttc'
        : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    'MaterialIcons':
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    await (FontLoader(entry.key)
          ..addFont(File(entry.value).readAsBytes().then(ByteData.sublistView)))
        .load();
  }
}

class MenuEvidenceBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  if (Platform.environment['RE0_CAPTURE_MENUS'] != null) MenuEvidenceBinding();
  setUpAll(loadMenuFonts);

  testWidgets('Desktop creation menus remain readable and allow the last ratio',
      (tester) async {
    await fixtures.mount(tester, const HomeScreen(), fixtures.FrontendGateway(),
        size: const Size(1440, 900));
    await tester.tap(find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text(AppBrands.re0.generateTabLabel)));
    await tester.pumpAndSettle();
    final ratio = find.byWidgetPredicate(
        (widget) => widget is CompactDropdownField && widget.label == '画面比例');
    await tester.ensureVisible(ratio);
    await tester.pumpAndSettle();
    await capture(tester, fixtures.boundary, 'creation-closed-1440');
    await tester.tap(ratio);
    await tester.pumpAndSettle();
    await capture(tester, fixtures.boundary, 'creation-ratio-1440');
    final lastLabel = imageAspectRatioOptions.last.label;
    final last = find.descendant(
        of: find.byType(MenuItemButton), matching: find.text(lastLabel));
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(tester.widget<CompactDropdownField>(ratio).value,
        imageAspectRatioOptions.last.value);
    await tester.tap(ratio);
    await tester.pumpAndSettle();
    final resolution = find.byWidgetPredicate(
        (widget) => widget is CompactDropdownField && widget.label == '分辨率');
    await tester.tap(resolution);
    await tester.pumpAndSettle();
    final ratioAnchor = tester.widget<MenuAnchor>(
        find.descendant(of: ratio, matching: find.byType(MenuAnchor)));
    final resolutionAnchor = tester.widget<MenuAnchor>(
        find.descendant(of: resolution, matching: find.byType(MenuAnchor)));
    expect(ratioAnchor.controller!.isOpen, isFalse);
    expect(resolutionAnchor.controller!.isOpen, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  for (final size in [const Size(900, 600), const Size(1440, 900)]) {
    testWidgets('Long options scroll, wrap, select and dismiss at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      var value = 18;
      final labels = List.generate(24, (i) => '选项 $i：完整的模型线路与图片参数名称');
      await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: AppBrands.re0.theme.copyWith(
                textTheme: AppBrands.re0.theme.textTheme
                    .apply(fontFamily: 'FrontendEvidence')),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!),
            home: Scaffold(
                body: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: StatefulBuilder(
                            builder: (context, update) =>
                                CompactDropdownField<int>(
                                  label: '模型线路',
                                  value: value,
                                  width: 148,
                                  selectedLabels: labels,
                                  items: [
                                    for (var i = 0; i < labels.length; i++)
                                      DropdownMenuItem(
                                          value: i,
                                          enabled: i != 19,
                                          child: Text(labels[i]))
                                  ],
                                  onChanged: (next) =>
                                      update(() => value = next!),
                                ))))),
          )));
      await tester.pumpAndSettle();
      final field = find.byType(CompactDropdownField<int>);
      await tester.tap(field);
      await tester.pumpAndSettle();
      final menu = find.byType(MenuItemButton).first;
      final surface = find
          .ancestor(
              of: menu,
              matching: find.byWidgetPredicate((widget) =>
                  widget is Material &&
                  widget.elevation == 4 &&
                  widget.type == MaterialType.canvas))
          .first;
      final bounds = tester.getRect(surface);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(size.width));
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.bottom, lessThanOrEqualTo(tester.getRect(field).top));
      expect(bounds.width, greaterThanOrEqualTo(224));
      await capture(tester, boundary, 'long-options-${size.width.toInt()}');
      final last = find.widgetWithText(MenuItemButton, labels.last);
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await capture(tester, boundary, 'long-last-${size.width.toInt()}');
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(value, 23);
      expect(find.byType(MenuItemButton), findsNothing);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
      anchor.childFocusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(anchor.childFocusNode!.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  }
}
