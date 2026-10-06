import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/api_error.dart';
import 'package:re0/core/app_brand.dart';
import 'package:re0/core/gateway_client.dart';
import 'package:re0/core/image_cache_service.dart';
import 'package:re0/core/image_capabilities.dart';
import 'package:re0/core/providers.dart';
import 'package:re0/features/chronogear/chronogear_screen.dart';
import 'package:re0/features/gallery/gallery_screen.dart';
import 'package:re0/features/home/home_screen.dart';
import 'package:re0/features/materializer/materializer_screen.dart';
import 'package:re0/features/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const fixtureUser = <String, dynamic>{
  'id': 'demo',
  'username': 'demo',
  'display_name': '爱蜜莉雅',
  'points': 128,
  'level_info': {'label': 'LV3'},
  'quota_summary': {
    'generate': {'remaining': 18, 'total': 20},
    'edit': {'remaining': 9, 'total': 10},
  },
};

class FrontendGateway extends GatewayClient {
  int galleryReads = 0, historyReads = 0, profileReads = 0, updateReads = 0;
  bool failGallery = false, failReaction = false;
  String? galleryKeyword, historyKeyword, galleryAction;
  int reactionCalls = 0, profileSaves = 0;
  bool failProfileSave = false;
  Completer<void>? profileSaveGate;
  Completer<Map<String, dynamic>>? galleryGate, reactionGate;

  @override
  Future<Map<String, dynamic>> getGalleryPosts(
      {required String view,
      String? keyword,
      String? action,
      String sort = 'time',
      int page = 1,
      int pageSize = 30}) async {
    galleryReads++;
    galleryKeyword = keyword;
    galleryAction = action;
    if (galleryGate != null) return galleryGate!.future;
    if (failGallery) throw const GatewayException('网络连接失败，请重试');
    return {
      'items': [
        for (var i = 0; i < 2; i++)
          {
            'id': 'post-$i',
            'user_id': 'artist',
            'display_name': '示例创作者',
            'prompt': '午后的光影与幻想世界',
            'image_url': 'https://example.test/demo-$i.png',
            'action': i == 0 ? 'generate' : 'edit',
            'created_at': '2026-10-04T08:00:00Z',
            'like_count': 8,
            'favorite_count': 3,
            'comment_count': 2,
          },
      ],
      'total_pages': 2
    };
  }

  @override
  Future<Map<String, dynamic>> getHistory(int page,
      {int pageSize = 30,
      String? keyword,
      String? action,
      String? status}) async {
    historyReads++;
    historyKeyword = keyword;
    return {'items': [], 'total': 0, 'total_pages': 1};
  }

  @override
  Future<Map<String, dynamic>> getDailyCheckInStatus() async {
    profileReads++;
    return {'signed_today': false};
  }

  @override
  Future<Map<String, dynamic>> getDailyImageDrawStatus() async =>
      {'drawn_today': false, 'can_draw': true};
  @override
  Future<Map<String, dynamic>> getMyNotifications(
          {int limit = 80, String? readState}) async =>
      {'items': [], 'unread_count': 2};
  @override
  Future<Map<String, dynamic>> checkAuth() async => fixtureUser;
  @override
  Future<Map<String, dynamic>> checkAppUpdate(
      String appId, int currentVersionCode) async {
    updateReads++;
    return {
      'available': true,
      'latest_version_code': currentVersionCode + 1,
      'latest_version_name': '1.2.99',
      'download_url': 'https://example.test/latest.apk',
      'release_notes': '服务器发布的新版',
      'file_size': 64000000
    };
  }

  @override
  Future<Map<String, dynamic>> updateMyProfile(
      String username, String displayName) async {
    profileSaves++;
    if (profileSaveGate != null) await profileSaveGate!.future;
    if (failProfileSave) throw const GatewayException('保存失败，请重试');
    return {...fixtureUser, 'username': username, 'display_name': displayName};
  }

  @override
  Future<Map<String, dynamic>> toggleGalleryLike(String id) async {
    reactionCalls++;
    if (reactionGate != null) return reactionGate!.future;
    if (failReaction) throw const GatewayException('点赞失败，请重试');
    return {'id': id, 'liked': true, 'like_count': 9};
  }
}

class FixtureImageCache extends ImageCacheService {
  @override
  Future<int> cacheSizeBytes() async => 2400000;
  @override
  Future<File> cachedFileFor(String url, {bool forceRefresh = false}) async =>
      File('assets/backgrounds/re0.png');
}

final boundary = GlobalKey();

Future<void> mount(WidgetTester tester, Widget screen, FrontendGateway gateway,
    {Size size = const Size(430, 900), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'active_brand': 're0'});
  final prefs = await SharedPreferences.getInstance();
  final theme = AppBrands.byId('re0').theme;
  await tester.pumpWidget(RepaintBoundary(
    key: boundary,
    child: ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          gatewayClientProvider.overrideWithValue(gateway),
          imageCacheProvider.overrideWithValue(FixtureImageCache()),
          imageCapabilitiesProvider
              .overrideWith((ref) async => ImageCapabilities.fallback()),
          authStateProvider.overrideWith((ref) => fixtureUser),
          energyProvider.overrideWith((ref) =>
              Map<String, dynamic>.from(fixtureUser['quota_summary'] as Map)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'FrontendEvidence'),
              primaryTextTheme:
                  theme.primaryTextTheme.apply(fontFamily: 'FrontendEvidence'),
              appBarTheme: theme.appBarTheme.copyWith(
                  titleTextStyle: theme.appBarTheme.titleTextStyle
                      ?.copyWith(fontFamily: 'FrontendEvidence')),
              inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                hintStyle: theme.inputDecorationTheme.hintStyle
                    ?.copyWith(fontFamily: 'FrontendEvidence'),
                labelStyle: theme.inputDecorationTheme.labelStyle
                    ?.copyWith(fontFamily: 'FrontendEvidence'),
              )),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: screen,
        )),
  ));
  await tester.pumpAndSettle(const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['RE0_CAPTURE_FRONTEND'] != '1') return;
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
  await tester.pump();
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final snapshot = await render.toImage(pixelRatio: 1.5);
    final data = await snapshot.toByteData(format: ui.ImageByteFormat.png);
    await File('evidence/screenshots/frontend-redesign-20261004/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    snapshot.dispose();
  });
}

Future<void> visible(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
          of: find.byType(ListView).first, matching: find.byType(Scrollable))
      .first;
  if (finder.evaluate().isEmpty)
    await tester.scrollUntilVisible(finder, 300, scrollable: scrollable);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle(const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
}

void main() {
  setUpAll(() async {
    if (Platform.environment['RE0_CAPTURE_FRONTEND'] == '1') {
      for (final font in {
        'FrontendEvidence':
            '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
        'MaterialIcons':
            '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final loader = FontLoader(font.key);
        loader.addFont(File(font.value)
            .readAsBytes()
            .then((data) => ByteData.sublistView(data)));
        await loader.load();
      }
    }
  });

  testWidgets('Home loads tabs on demand and retains gallery search on return',
      (tester) async {
    final gateway = FrontendGateway();
    await mount(tester, const HomeScreen(), gateway);
    expect(gateway.galleryReads, 1);
    expect(gateway.historyReads, 0);
    expect(gateway.profileReads, 0);
    await tester.enterText(find.byType(TextField).first, '风景');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(AppBrands.re0.generateTabLabel)));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await capture(tester, 'generate-phone');
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(AppBrands.re0.galleryTabLabel)));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '风景');
    expect(gateway.galleryKeyword, '风景');
    await capture(tester, 'gallery-phone');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Gallery has a retry state and queues filter changes during a request',
      (tester) async {
    final gateway = FrontendGateway()..failGallery = true;
    await mount(tester, const GalleryScreen(), gateway);
    expect(find.text('读取画廊失败'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    gateway.failGallery = false;
    await tester.tap(find.widgetWithText(OutlinedButton, '重试'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('示例创作者'), findsNWidgets(2));
    gateway.galleryGate = Completer<Map<String, dynamic>>();
    await tester.enterText(find.byType(TextField).first, 'one');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, 'two');
    await tester.pump(const Duration(milliseconds: 400));
    final gate = gateway.galleryGate!;
    gateway.galleryGate = null;
    gate.complete({'items': [], 'total_pages': 1});
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(gateway.galleryKeyword, 'two');
    expect(gateway.galleryReads, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gallery reports reaction errors and prevents repeated taps',
      (tester) async {
    final gateway = FrontendGateway()
      ..reactionGate = Completer<Map<String, dynamic>>();
    await mount(tester, const GalleryScreen(), gateway);
    final like = find
        .ancestor(
            of: find.byIcon(Icons.favorite_border).first,
            matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(like);
    await tester.tap(like);
    await tester.pump();
    await tester.tap(like);
    expect(gateway.reactionCalls, 1);
    gateway.reactionGate!.completeError(const GatewayException('点赞失败，请重试'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('点赞失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('History retains its filters when returning to the tab',
      (tester) async {
    final gateway = FrontendGateway();
    await mount(tester, const HomeScreen(), gateway);
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(AppBrands.re0.historyTabLabel)));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.enterText(find.byType(TextField).first, '森林');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.tap(find.text('失败'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(AppBrands.re0.editTabLabel)));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(AppBrands.re0.historyTabLabel)));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(gateway.historyKeyword, '森林');
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '森林');
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '失败'))
            .selected,
        isTrue);
    expect(tester.takeException(), isNull);
    await capture(tester, 'history-phone');
  });

  testWidgets('Profile checks the gateway update and opens a full theme list',
      (tester) async {
    final gateway = FrontendGateway();
    await mount(tester, const ProfileScreen(), gateway);
    await capture(tester, 'profile-phone');
    await visible(tester, find.text('检查更新'));
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(gateway.updateReads, 1);
    expect(find.text('发现新版本 1.2.99'), findsOneWidget);
    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await visible(tester, find.text('主题风格'));
    await tester.tap(find.text('主题风格'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(AppBrands.all.last.appTitle), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final edit in [false, true]) {
    for (final size in [const Size(360, 800), const Size(1000, 1000)]) {
      testWidgets(
          '${edit ? 'Edit' : 'Generate'} fits $size with large text and keyboard',
          (tester) async {
        await mount(
            tester,
            edit ? const ChronogearScreen() : const MaterializerScreen(),
            FrontendGateway(),
            size: size,
            scale: size.width < 400 ? 1.4 : 1);
        final prompt = find.byType(TextField).first;
        await tester.enterText(prompt, '森林里的阳光，柔和光影');
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle(const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
        await tester.ensureVisible(prompt);
        await tester.pumpAndSettle(const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
        expect(tester.getBottomLeft(prompt).dy, lessThan(size.height - 280));
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle(const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
        await capture(tester,
            '${edit ? 'edit' : 'generate'}-${size.width < 400 ? 'small' : 'tablet'}');
        await tester.ensureVisible(find.text('图片设置'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
        await tester.tap(find.text('高级设置'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
        expect(find.text('文件格式'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Profile form keeps edits on failure and blocks duplicate saving',
      (tester) async {
    final gateway = FrontendGateway()..failProfileSave = true;
    await mount(tester, const ProfileScreen(), gateway,
        size: const Size(360, 800), scale: 1.4);
    await visible(tester, find.text('个人资料'));
    await tester.tap(find.text('个人资料'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();
    final field = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == '显示名称');
    await tester.enterText(field, '新的昵称');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '新的昵称');
    gateway.failProfileSave = false;
    gateway.profileSaveGate = Completer<void>();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存中…'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
            .onPressed,
        isNull);
    expect(gateway.profileSaves, 2);
    gateway.profileSaveGate!.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wide home uses a navigation rail', (tester) async {
    await mount(tester, const HomeScreen(), FrontendGateway(),
        size: const Size(1000, 1000));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await capture(tester, 'gallery-tablet');
    expect(tester.takeException(), isNull);
  });
}
