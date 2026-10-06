import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:re0/core/app_brand.dart';
import 'package:re0/core/api_error.dart';
import 'package:re0/core/image_capabilities.dart';
import 'package:re0/core/providers.dart';
import 'package:re0/core/stable_form_dialog.dart';
import 'package:re0/features/admin/admin_screen.dart';
import 'package:re0/features/home/home_screen.dart';
import 'package:re0/features/materializer/materializer_screen.dart';
import 'package:re0/features/profile/profile_screen.dart';
import 'package:re0/features/gallery/gallery_collections_screen.dart';
import 'package:re0/features/gallery/gallery_detail_screen.dart';
import 'package:re0/features/feedback/admin_feedback_panel.dart';

import 'frontend_management_test.dart' as frontend;
import 'admin_management_test.dart' as admin;
import 'admin_generation_settings_test.dart' show settingField;

final boundary = GlobalKey();

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5));

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['RE0_CAPTURE_THEME'] != '1') return;
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
  await tester.pump();
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final snapshot = await render.toImage(pixelRatio: 1.5);
    final bytes = await snapshot.toByteData(format: ui.ImageByteFormat.png);
    await File('evidence/screenshots/theme-settings-fixes-20261005/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    snapshot.dispose();
  });
}

Future<void> mountBrand(WidgetTester tester, AppBrand brand, Widget screen,
    {double scale = 1,
    double width = 360,
    frontend.FrontendGateway? gateway,
    bool liveCapabilities = false}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'active_brand': brand.id});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(RepaintBoundary(
    key: boundary,
    child: ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        gatewayClientProvider
            .overrideWithValue(gateway ?? frontend.FrontendGateway()),
        imageCacheProvider.overrideWithValue(frontend.FixtureImageCache()),
        authStateProvider.overrideWith((ref) => frontend.fixtureUser),
        energyProvider.overrideWith((ref) => Map<String, dynamic>.from(
            frontend.fixtureUser['quota_summary'] as Map)),
        if (!liveCapabilities)
          imageCapabilitiesProvider
              .overrideWith((ref) async => ImageCapabilities.fallback()),
      ],
      child: Consumer(builder: (context, ref, _) {
        final theme = ref.watch(brandProvider).theme;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'FrontendEvidence'),
            primaryTextTheme:
                theme.primaryTextTheme.apply(fontFamily: 'FrontendEvidence'),
            appBarTheme: theme.appBarTheme.copyWith(
                titleTextStyle: theme.appBarTheme.titleTextStyle
                    ?.copyWith(fontFamily: 'FrontendEvidence')),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        );
      }),
    ),
  ));
  await settle(tester);
}

Future<void> tab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text(label)));
  await settle(tester);
}

class PriceSettingsGateway extends admin.ManagementGateway {
  int capabilityReads = 0;
  @override
  Future<Map<String, dynamic>> imageCapabilities() async {
    capabilityReads++;
    final multiplier =
        double.parse(values['vip_image_quota_multiplier'].toString());
    return priceMetadata(multiplier);
  }
}

Map<String, dynamic> priceMetadata(double multiplier) => {
      'image_modes': {
        'current': 'vip',
        'allowed': ['vip', 'general'],
        'vip_quota_multiplier': multiplier,
        'vip_quota_per_image': (2 * multiplier).ceil(),
        'general_quota_per_image': 1,
      },
    };

class PriceFrontendGateway extends frontend.FrontendGateway {
  double multiplier = 0.5;
  int reads = 0;
  @override
  Future<Map<String, dynamic>> imageCapabilities() async {
    reads++;
    return priceMetadata(multiplier);
  }
}

class ReplyGateway extends frontend.FrontendGateway {
  static const item = {
    'id': 'feedback-example',
    'title': '示例反馈',
    'content': '请查看处理进度',
    'status': 'pending',
    'type': 'feedback',
  };
  bool fail = true;
  int saves = 0;
  String? savedReply;
  Completer<void>? saving;

  @override
  Future<Map<String, dynamic>> getAdminFeedback({
    String? type,
    String? category,
    String? status,
    String? keyword,
    DateTime? startAt,
    DateTime? endAt,
    int page = 1,
    int pageSize = 30,
  }) async =>
      {
        'items': [item],
        'total': 1
      };

  @override
  Future<Map<String, dynamic>> getAdminFeedbackDetail(String id) async => item;

  @override
  Future<Map<String, dynamic>> replyAdminFeedback(
      String id, String reply) async {
    saves++;
    if (saving != null) await saving!.future;
    if (fail) throw const GatewayException('保存失败，请重试');
    savedReply = reply;
    return {...item, 'admin_reply': reply};
  }

  @override
  Future<List<Map<String, dynamic>>> getGalleryComments(String postId) async =>
      [];
}

Finder dialogSurface() => find
    .descendant(of: find.byType(Dialog), matching: find.byType(Material))
    .first;

Future<void> keyboardSequence(WidgetTester tester, Size size) async {
  final before = tester.getRect(dialogSurface());
  for (final inset in [40.0, 120.0, 220.0, 280.0, 200.0, 80.0, 0.0]) {
    tester.view.viewInsets = FakeViewPadding(bottom: inset);
    await tester.pump(const Duration(milliseconds: 16));
    final current = tester.getRect(dialogSurface());
    expect(current.top, closeTo(before.top, 0.1),
        reason:
            'Keyboard metrics must not move the floating form up and down.');
    expect(current.left, closeTo(before.left, 0.1));
    expect(current.bottom, lessThanOrEqualTo(size.height - inset + 0.1));
    expect(tester.takeException(), isNull);
  }
  await settle(tester);
}

void main() {
  setUpAll(() async {
    if (Platform.environment['RE0_CAPTURE_THEME'] != '1') return;
    for (final family in [
      'FrontendEvidence',
      'AdminEvidence',
      'sans-serif',
      'MaterialIcons'
    ]) {
      final loader = FontLoader(family);
      final path = family == 'MaterialIcons'
          ? '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
          : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc';
      loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  for (final entry in [
    for (final brand in AppBrands.all) (brand, 1.0),
    (AppBrands.re0, 2.0),
    (AppBrands.botw, 2.0),
  ]) {
    final brand = entry.$1;
    testWidgets('${brand.id} restores theme copy at ${entry.$2} scale',
        (tester) async {
      await mountBrand(tester, brand, const HomeScreen(),
          scale: entry.$2, width: entry.$2 == 1 ? 360 : 320);
      final destinations = tester.widgetList<NavigationDestination>(
          find.byType(NavigationDestination));
      expect(destinations.map((item) => item.label), [
        brand.galleryTabLabel,
        brand.generateTabLabel,
        brand.editTabLabel,
        brand.historyTabLabel,
        '我的',
      ]);
      await tab(tester, brand.generateTabLabel);
      expect(find.text(brand.generateTitle), findsOneWidget);
      expect(find.text(brand.promptLabel), findsOneWidget);
      expect(find.text('${brand.generateQuotaLabel}: 18 / 20'), findsOneWidget);
      final prompt = tester.widget<TextField>(find.byType(TextField).first);
      expect(prompt.decoration?.hintText, brand.generatePromptHint);
      await capture(tester, boundary, '${brand.id}-generate-${entry.$2}');
      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, brand.generateButtonLabel));
      expect(tester.takeException(), isNull);
      await tab(tester, brand.editTabLabel);
      expect(find.text(brand.editTitle), findsOneWidget);
      expect(find.text(brand.editPromptLabel), findsOneWidget);
      expect(find.text(brand.pickImageText), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .decoration
              ?.hintText,
          brand.editPromptHint);
      await capture(tester, boundary, '${brand.id}-edit-${entry.$2}');
      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, brand.editButtonLabel));
      await tab(tester, brand.historyTabLabel);
      expect(find.text(brand.historyTitle), findsOneWidget);
      expect(find.text(brand.emptyHistoryText), findsOneWidget);
      await tester.runAsync(() async {});
      Navigator.of(tester.element(find.byType(HomeScreen))).push(
          MaterialPageRoute<void>(
              builder: (_) => const GalleryCollectionsScreen()));
      await settle(tester);
      expect(find.text(brand.favoriteTabLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
      final theme = brand.theme;
      expect(theme.colorScheme.outlineVariant,
          theme.colorScheme.primary.withValues(alpha: 0.14));
      expect(theme.dividerTheme.color,
          theme.colorScheme.primary.withValues(alpha: 0.16));
      expect(theme.dividerTheme.thickness, 0.6);
    });
  }

  testWidgets('Saving VIP multiplier refreshes a previously cached price',
      (tester) async {
    final gateway = PriceSettingsGateway();
    await admin.mountAdmin(tester, gateway,
        view: 'settings', theme: AppBrands.re0.theme);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(AdminScreen)));
    expect(
        (await container.read(imageCapabilitiesProvider.future))
            .imageModes
            .effectiveVipQuotaPerImage,
        1);
    final edit = find.byTooltip('编辑基础设置');
    await admin.visible(tester, edit);
    await tester.tap(edit);
    await settle(tester);
    await tester.ensureVisible(settingField('VIP 图片额度倍率'));
    await tester.enterText(settingField('VIP 图片额度倍率'), '5');
    await settle(tester);
    expect(find.textContaining('当前 10 额度/张'), findsOneWidget);
    await capture(tester, admin.boundaryKey, 'vip-rate-preview');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await settle(tester);
    expect(gateway.submitted, {'vip_image_quota_multiplier': 5.0});
    final refreshed = await container.read(imageCapabilitiesProvider.future);
    expect(refreshed.imageModes.effectiveVipQuotaPerImage, 10);
    expect(refreshed.imageModes.vipQuotaMultiplier, 5);
    expect(gateway.capabilityReads, greaterThanOrEqualTo(2));
    Navigator.of(tester.element(find.byType(AdminScreen))).push(
        MaterialPageRoute<void>(builder: (_) => const MaterializerScreen()));
    await settle(tester);
    expect(find.textContaining('VIP:10额度/张（5倍）'), findsOneWidget);
    await capture(tester, admin.boundaryKey, 'vip-price-refreshed');
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Returning to foreground refreshes an externally changed price',
      (tester) async {
    final gateway = PriceFrontendGateway();
    await mountBrand(tester, AppBrands.re0, const HomeScreen(),
        gateway: gateway, liveCapabilities: true);
    await tab(tester, AppBrands.re0.generateTabLabel);
    expect(find.textContaining('VIP:1额度/张'), findsOneWidget);
    gateway.multiplier = 5;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(tester);
    expect(find.textContaining('VIP:10额度/张（5倍）'), findsOneWidget);
    expect(gateway.reads, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  for (final entry in [
    (const Size(360, 800), 1.0),
    (const Size(320, 800), 2.0),
    (const Size(1000, 600), 1.2)
  ]) {
    testWidgets('Settings dialog stays anchored for keyboard at $entry',
        (tester) async {
      await admin.mountAdmin(tester, PriceSettingsGateway(),
          view: 'settings',
          size: entry.$1,
          scale: entry.$2,
          theme: AppBrands.re0.theme);
      await admin.openGeneration(tester);
      final field = settingField('主用生图模型');
      await tester.ensureVisible(field);
      await settle(tester);
      await tester.tap(field);
      await settle(tester);
      addTearDown(tester.view.resetViewInsets);
      final decoration = Theme.of(tester.element(field)).inputDecorationTheme;
      expect(decoration.enabledBorder!.borderSide.width, 0.8);
      expect(decoration.enabledBorder!.borderSide.color,
          AppBrands.re0.primaryColor.withValues(alpha: 0.24));
      expect(decoration.focusedBorder!.borderSide.width, 1.2);
      await keyboardSequence(tester, entry.$1);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.widgetWithText(FilledButton, '保存').hitTestable(),
          findsOneWidget);
      await capture(tester, admin.boundaryKey,
          'settings-keyboard-${entry.$1.width.toInt()}');
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await settle(tester);
    });
  }

  testWidgets(
      'Profile edit stays anchored while opening and closing the keyboard',
      (tester) async {
    await mountBrand(tester, AppBrands.re0, const ProfileScreen());
    await frontend.visible(tester, find.text('个人资料'));
    await tester.tap(find.text('个人资料'));
    await settle(tester);
    await tester.tap(find.text('编辑资料'));
    await settle(tester);
    expect(find.byType(StableFormDialog), findsOneWidget);
    final field = settingField('显示名称');
    await tester.tap(field);
    await tester.enterText(field, 'updateduser');
    addTearDown(tester.view.resetViewInsets);
    await keyboardSequence(tester, const Size(360, 800));
    expect(tester.widget<TextField>(field).controller!.text, 'updateduser');
    await capture(tester, boundary, 'profile-stable-form');
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Admin reply keeps its draft and supports retry in a stable dialog',
      (tester) async {
    final gateway = ReplyGateway();
    await mountBrand(
        tester,
        AppBrands.re0,
        const Scaffold(
            body: AdminFeedbackPanel(
                canManage: false, canReply: true, canAi: false)),
        gateway: gateway);
    await tester.ensureVisible(find.text('示例反馈'));
    await tester.tap(find.text('示例反馈'));
    await settle(tester);
    final replyButton = find.widgetWithText(FilledButton, '回复');
    await tester.ensureVisible(replyButton);
    await tester.tap(replyButton);
    await settle(tester);
    final field = find.descendant(
        of: find.byType(StableFormDialog), matching: find.byType(TextField));
    await tester.enterText(field, '已经记录，正在修复。');
    addTearDown(tester.view.resetViewInsets);
    await keyboardSequence(tester, const Size(360, 800));
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await settle(tester);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '已经记录，正在修复。');
    await capture(tester, boundary, 'admin-reply-draft-retained');
    gateway.fail = false;
    gateway.saving = Completer<void>();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存中…'))
            .onPressed,
        isNull);
    expect(gateway.saves, 2);
    gateway.saving!.complete();
    await settle(tester);
    expect(gateway.savedReply, '已经记录，正在修复。');
    expect(find.byType(StableFormDialog), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gallery comment controls track every keyboard frame',
      (tester) async {
    await mountBrand(
        tester,
        AppBrands.re0,
        const GalleryDetailScreen(initialPost: {
          'id': 'gallery-example',
          'image_url': '',
          'display_name': '示例用户',
          'prompt': '示例图片',
        }),
        gateway: ReplyGateway(),
        scale: 1.4);
    await tester.tap(find.text('写评论'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '喜欢这个画面');
    addTearDown(tester.view.resetViewInsets);
    final send = find.widgetWithText(FilledButton, '发送');
    for (final inset in [40.0, 120.0, 220.0, 280.0, 160.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getRect(send).bottom, lessThanOrEqualTo(800 - inset));
      expect(send.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '喜欢这个画面');
    await capture(tester, boundary, 'gallery-comment-keyboard');
  });
}
