import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/app_brand.dart';
import 'package:re0/features/home/home_screen.dart';
import 'package:re0/features/compendium/image_preview_screen.dart';
import 'frontend_management_test.dart' as fixtures;

void main() {
  setUpAll(() async {
    if (Platform.environment['RE0_CAPTURE_DESKTOP'] != '1') return;
    for (final entry in {
      'FrontendEvidence':
          '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      'MaterialIcons':
          '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)
            ..addFont(
                File(entry.value).readAsBytes().then(ByteData.sublistView)))
          .load();
    }
  });
  Future<void> capture(WidgetTester tester, String name) async {
    if (Platform.environment['RE0_CAPTURE_DESKTOP'] != '1') return;
    await tester.runAsync(() async {
      final boundary = fixtures.boundary.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file =
          File('evidence/screenshots/desktop-experience-20261006/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [1440.0, 1920.0, 900.0]) {
    testWidgets('Desktop home workbench at width $width', (tester) async {
      await fixtures.mount(
          tester, const HomeScreen(), fixtures.FrontendGateway(),
          size: Size(width, 900));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      // A mouse click also covers navigation when no initial key focus exists.
      if (find.text(AppBrands.re0.generateTitle).evaluate().isEmpty) {
        await tester.tap(find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(AppBrands.re0.generateTabLabel)));
        await tester.pumpAndSettle();
      }
      expect(find.text(AppBrands.re0.generateTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'windows-workspace-${width.toInt()}');
    });
  }
  testWidgets('Preview supports keyboard navigation and zoom without page drag',
      (tester) async {
    await fixtures.mount(
        tester,
        const ImagePreviewScreen(showDownload: false, items: [
          PreviewImageEntry(
              url: '', filePath: 'assets/backgrounds/re0.png', title: '预览一'),
          PreviewImageEntry(
              url: '', filePath: 'assets/backgrounds/re0.png', title: '预览二'),
        ]),
        fixtures.FrontendGateway(),
        size: const Size(1440, 900));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('预览二'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pumpAndSettle();
    final interactive =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer).last);
    expect(interactive.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pumpAndSettle();
    expect(interactive.transformationController!.value.getMaxScaleOnAxis(), 1);
    await capture(tester, 'windows-preview');
    expect(tester.takeException(), isNull);
  });
}
