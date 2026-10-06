import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/brand_background.dart';
import 'package:re0/core/app_brand.dart';
import 'package:re0/core/prompt_assist_copy.dart';
import 'package:re0/core/prompt_candidate_toolbar.dart';
import 'package:re0/features/home/home_screen.dart';

import 'frontend_management_test.dart' as fixtures;

const candidates = ['午后窗边的橘猫，柔和光影', '雨夜街道，电影灯光', '森林里的阳光，写实摄影'];

class StyleGateway extends fixtures.FrontendGateway {
  @override
  Future<List<String>> generatePromptCandidates(String idea) async =>
      candidates;

  @override
  Future<List<String>> generateEditPromptCandidates(String idea,
          {bool divergent = false}) async =>
      candidates;
}

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5));

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['RE0_CAPTURE_STYLE'] != '1') return;
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
  await tester.pump();
  await tester.runAsync(() async {
    final render = fixtures.boundary.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final snapshot = await render.toImage(pixelRatio: 1.5);
    final data = await snapshot.toByteData(format: ui.ImageByteFormat.png);
    await File('evidence/screenshots/style-fixes-20261005/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    snapshot.dispose();
  });
}

Future<void> openTab(WidgetTester tester, bool edit) async {
  final navigation = find.byType(NavigationBar).evaluate().isNotEmpty
      ? find.byType(NavigationBar)
      : find.byType(NavigationRail);
  await tester.tap(find.descendant(
      of: navigation,
      matching: find.text(
          edit ? AppBrands.re0.editTabLabel : AppBrands.re0.generateTabLabel)));
  await settle(tester);
}

void main() {
  setUpAll(() async {
    // Screenshot verification uses real glyphs; ordinary tests also run without
    // depending on system fonts or the workspace's Flutter installation path.
    if (Platform.environment['RE0_CAPTURE_STYLE'] != '1') return;
    for (final font in {
      'FrontendEvidence':
          '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      'MaterialIcons':
          '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(font.key);
      loader.addFont(File(font.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  testWidgets('Wallpaper cannot paint beyond its page overlay', (tester) async {
    await fixtures.mount(
        tester,
        const Stack(children: [
          Positioned.fill(child: ColoredBox(color: Color(0xFFFF0000))),
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: BrandBackground(child: SizedBox.shrink())),
        ]),
        StyleGateway());
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/backgrounds/re0.png'),
        tester.element(find.byType(BrandBackground))));
    await tester.pump();
    await tester.runAsync(() async {
      final render = fixtures.boundary.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final snapshot = await render.toImage();
      final data =
          await snapshot.toByteData(format: ui.ImageByteFormat.rawRgba);
      final outside = (200 * snapshot.width + 100) * 4;
      expect(data!.buffer.asUint8List().sublist(outside, outside + 4),
          [255, 0, 0, 255],
          reason: 'Wallpaper must not cover neighboring content.');
      snapshot.dispose();
    });
  });

  for (final edit in [false, true]) {
    for (final size in [const Size(360, 800), const Size(1000, 600)]) {
      testWidgets('Home ${edit ? 'edit' : 'generate'} meets keyboard at $size',
          (tester) async {
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        await fixtures.mount(tester, const HomeScreen(), StyleGateway(),
            size: size, scale: 1.4);
        await openTab(tester, edit);
        final prompt = find.byType(TextField).first;
        await tester.enterText(prompt, '森林里的阳光，柔和光影');
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        tester.view.padding = const FakeViewPadding(top: 24);
        await settle(tester);
        final background = find.byType(BrandBackground);
        expect(tester.getBottomLeft(background).dy,
            closeTo(size.height - 280, 0.1),
            reason:
                'The page must meet the keyboard without a navigation gap.');
        expect(find.byType(NavigationBar), findsNothing);
        await tester.ensureVisible(prompt);
        await settle(tester);
        expect(tester.getBottomLeft(prompt).dy, lessThan(size.height - 280));
        expect(tester.takeException(), isNull);
        await capture(tester,
            '${edit ? 'edit' : 'generate'}-keyboard-${size.width.toInt()}');
        tester.view.resetViewInsets();
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        await settle(tester);
        if (size.width < 840)
          expect(find.byType(NavigationBar), findsOneWidget);
        expect(
            tester.widget<TextField>(prompt).controller!.text, '森林里的阳光，柔和光影');
        expect(tester.takeException(), isNull);
      });
    }

    for (final setting in [(430.0, 1.0), (360.0, 1.4), (320.0, 2.0)]) {
      testWidgets(
          '${edit ? 'Edit' : 'Generate'} candidate controls stay together at $setting',
          (tester) async {
        await fixtures.mount(tester, const HomeScreen(), StyleGateway(),
            size: Size(setting.$1, 900), scale: setting.$2);
        await openTab(tester, edit);
        await tester.ensureVisible(find.text('AI 提示词助手'));
        await tester.tap(find.text('AI 提示词助手'));
        await settle(tester);
        final idea = find.byWidgetPredicate((widget) =>
            widget is TextField &&
            widget.decoration?.labelText?.endsWith(edit ? '意图' : '思路') == true);
        await tester.ensureVisible(idea);
        await tester.enterText(idea, '午后窗边的橘猫');
        await tester.ensureVisible(find.widgetWithText(
            FilledButton, promptAssistCopyFor(AppBrands.re0).ideaAction));
        await tester.tap(find.widgetWithText(
            FilledButton, promptAssistCopyFor(AppBrands.re0).ideaAction));
        await settle(tester);
        await tester.pump(const Duration(seconds: 2));
        await settle(tester);
        await tester.ensureVisible(find.byType(PromptCandidateToolbar));
        await settle(tester);
        final all = tester.getCenter(find.widgetWithText(TextButton, '查看全部'));
        final previous = tester.getCenter(find.byIcon(Icons.chevron_left));
        final next = tester.getCenter(find.byIcon(Icons.chevron_right));
        expect(previous.dy, closeTo(all.dy, 0.1));
        expect(next.dy, closeTo(all.dy, 0.1));
        expect(previous.dx, lessThan(next.dx));
        expect(tester.takeException(), isNull);
        await capture(tester,
            '${edit ? 'edit' : 'generate'}-candidates-${setting.$1.toInt()}');
        await tester.tap(find.byIcon(Icons.chevron_right));
        await settle(tester);
        expect(
            find.text(edit
                ? promptAssistCopyFor(AppBrands.re0).editSwitcherLabel(1, 3)
                : promptAssistCopyFor(AppBrands.re0)
                    .generateSwitcherLabel(1, 3)),
            findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, '查看全部'));
        await settle(tester);
        expect(find.byType(Dialog), findsOneWidget);
        final list = find
            .descendant(
                of: find.descendant(
                    of: find.byType(Dialog), matching: find.byType(ListView)),
                matching: find.byType(Scrollable))
            .first;
        await tester.scrollUntilVisible(find.text(candidates.last), 180,
            scrollable: list);
        await settle(tester);
        expect(find.text(candidates.last), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester,
            '${edit ? 'edit' : 'generate'}-dialog-${setting.$1.toInt()}');
      });
    }
  }
}
