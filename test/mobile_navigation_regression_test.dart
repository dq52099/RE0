import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/app_brand.dart';
import 'package:re0/core/brand_background.dart';
import 'package:re0/core/cached_gateway_image.dart';
import 'package:re0/features/home/home_screen.dart';

import 'frontend_management_test.dart' as fixtures;
import 'mobile_admin_regression_test.dart' show capture;

class HistoryGateway extends fixtures.FrontendGateway {
  Completer<Map<String, dynamic>>? historyGate;

  Map<String, dynamic> get history => {
        'items': [
          {
            'id': 'saved-image',
            'url': 'https://example.test/saved.png',
            'status': 'success',
            'action': 'generate',
            'prompt': '午后的光影',
            'created_at': '2026-10-06T08:00:00Z',
          }
        ],
        'total': 1,
        'total_pages': 1,
      };

  @override
  Future<Map<String, dynamic>> getHistory(int page,
      {int pageSize = 30,
      String? keyword,
      String? action,
      String? status}) async {
    if (historyGate != null) return historyGate!.future;
    return history;
  }
}

void main() {
  setUpAll(() async {
    if (Platform.environment['RE0_CAPTURE_MOBILE_FIXES'] == null) return;
    for (final family in ['FrontendEvidence', 'MaterialIcons']) {
      final loader = FontLoader(family);
      loader.addFont(File(family == 'MaterialIcons'
              ? '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
              : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
          .readAsBytes()
          .then(ByteData.sublistView));
      await loader.load();
    }
  });

  testWidgets('All bottom destinations keep header and wallpaper still',
      (tester) async {
    await fixtures.mount(tester, const HomeScreen(), fixtures.FrontendGateway(),
        size: const Size(360, 800));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/backgrounds/re0.png'),
        tester.element(find.byType(BrandBackground))));
    final nav = find.byType(NavigationBar);
    final navigationRect = tester.getRect(nav);
    final brand = AppBrands.re0;
    for (final label in [
      brand.generateTabLabel,
      brand.editTabLabel,
      brand.historyTabLabel,
      '我的',
      brand.galleryTabLabel
    ]) {
      await tester.tap(find.descendant(of: nav, matching: find.text(label)));
      await tester.pump();
      final header = tester.getRect(find.byType(AppBar).first);
      final background = tester.getRect(find.byType(BrandBackground).first);
      for (final time in [16, 40, 100, 240]) {
        await tester.pump(Duration(milliseconds: time));
        expect(tester.getRect(nav), navigationRect);
        expect(tester.getRect(find.byType(AppBar).first), header);
        expect(tester.getRect(find.byType(BrandBackground).first), background);
        if (label == brand.generateTabLabel) {
          await capture(tester, fixtures.boundary, 'navigation-$time');
        }
      }
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Returning to gallery refreshes without pushing existing images down',
      (tester) async {
    final gateway = fixtures.FrontendGateway();
    await fixtures.mount(tester, const HomeScreen(), gateway);
    final image = find.byType(CachedGatewayImage).first;
    final position = tester.getTopLeft(image);
    final nav = find.byType(NavigationBar);
    await tester.tap(find.descendant(
        of: nav, matching: find.text(AppBrands.re0.generateTabLabel)));
    await tester.pumpAndSettle();
    final pending = Completer<Map<String, dynamic>>();
    gateway.galleryGate = pending;
    await tester.tap(find.descendant(
        of: nav, matching: find.text(AppBrands.re0.galleryTabLabel)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(image), position,
        reason:
            'Refresh feedback must not insert extra height above saved content.');
    gateway.galleryGate = null;
    pending.complete(await gateway.getGalleryPosts(view: 'all'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(image), position);
    // A failed background refresh must retain both existing images and layout.
    gateway.failGallery = true;
    await tester.tap(find.descendant(
        of: nav, matching: find.text(AppBrands.re0.generateTabLabel)));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: nav, matching: find.text(AppBrands.re0.galleryTabLabel)));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(image), position);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Returning to scrolled history keeps pagination and scroll position',
      (tester) async {
    final gateway = HistoryGateway();
    await fixtures.mount(tester, const HomeScreen(), gateway);
    final nav = find.byType(NavigationBar);
    Future<void> select(String label) async {
      await tester.tap(find.descendant(of: nav, matching: find.text(label)));
      await tester.pump();
    }

    await select(AppBrands.re0.historyTabLabel);
    await tester.pumpAndSettle();
    final pagination = find.text('第1/1页');
    await tester.ensureVisible(pagination);
    await tester.pumpAndSettle();
    final position = tester.getTopLeft(pagination);
    final scroll = tester.state<ScrollableState>(find.descendant(
        of: find.byType(CustomScrollView), matching: find.byType(Scrollable)));
    final offset = scroll.position.pixels;
    expect(offset, greaterThan(0));

    await select(AppBrands.re0.generateTabLabel);
    await tester.pumpAndSettle();
    gateway.historyGate = Completer<Map<String, dynamic>>();
    await select(AppBrands.re0.historyTabLabel);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(pagination), position);
    expect(scroll.position.pixels, offset);
    gateway.historyGate!.complete(gateway.history);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(pagination), position);
    expect(scroll.position.pixels, offset);
    expect(tester.takeException(), isNull);
  });
}
