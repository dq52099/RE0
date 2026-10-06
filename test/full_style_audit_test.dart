import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re0/features/gallery/gallery_screen.dart';
import 'package:re0/features/compendium/compendium_screen.dart';
import 'package:re0/features/profile/profile_screen.dart';
import 'package:re0/features/gallery/gallery_collections_screen.dart';
import 'package:re0/features/gallery/gallery_detail_screen.dart';
import 'package:re0/features/auth/login_screen.dart';
import 'package:re0/features/auth/register_screen.dart';
import 'package:re0/features/auth/password_reset_screen.dart';
import 'package:re0/features/feedback/feedback_screen.dart';

import 'frontend_management_test.dart' as frontend;
import 'admin_management_test.dart' as admin;

class LongContentGateway extends frontend.FrontendGateway {
  @override
  Future<List<Map<String, dynamic>>> getGalleryComments(String postId) async =>
      [];
  @override
  Future<void> init(String url) async {}
  @override
  Future<Map<String, dynamic>> bootstrap() async => {
        'allow_public_registration': true,
        'registration_email_required': true,
        'registration_invitation_required': false,
      };
  @override
  Future<Map<String, dynamic>> getMyFeedback(
          {String? type,
          String? category,
          String? status,
          String? keyword,
          int page = 1,
          int pageSize = 30}) async =>
      {'items': [], 'total': 0};
  @override
  Future<Map<String, dynamic>> getHistory(int page,
          {int pageSize = 30,
          String? keyword,
          String? action,
          String? status}) async =>
      {
        'items': [
          {
            'id': 'failed-demo',
            'status': 'failed',
            'action': 'generate',
            'prompt': '慵懒睡衣，真人漫展，柔和光线，保留人物和背景细节',
            'error': '上游图片生成超时，请稍后重试。已检查服务状态，当前仍未返回图片结果。',
            'size': '1200x675',
            'quality': 'high',
            'created_at': '2026-10-05T08:00:00Z',
          }
        ],
        'total': 1,
        'total_pages': 1,
      };

  @override
  Future<Map<String, dynamic>> getGalleryPosts({
    required String view,
    String? keyword,
    String? action,
    String sort = 'time',
    int page = 1,
    int pageSize = 30,
  }) async {
    final data = await super.getGalleryPosts(
        view: view,
        keyword: keyword,
        action: action,
        sort: sort,
        page: page,
        pageSize: pageSize);
    for (final item in data['items'] as List) {
      item['display_name'] = '名字很长的示例创作者爱蜜莉雅';
      item['like_count'] = 12345678;
      item['favorite_count'] = 87654321;
      item['comment_count'] = 1234567;
    }
    return data;
  }
}

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5));

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['RE0_CAPTURE_AUDIT'] != '1') return;
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
  await tester.pump();
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final snapshot = await render.toImage(pixelRatio: 1.5);
    final data = await snapshot.toByteData(format: ui.ImageByteFormat.png);
    await File('evidence/screenshots/full-style-audit-20261005/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    snapshot.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (Platform.environment['RE0_CAPTURE_AUDIT'] != '1') return;
    for (final family in [
      'FrontendEvidence',
      'AdminEvidence',
      'MaterialIcons'
    ]) {
      final file = family == 'MaterialIcons'
          ? '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
          : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc';
      final loader = FontLoader(family);
      loader.addFont(File(file).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  for (final entry in <String, Widget>{
    'gallery': const GalleryScreen(),
    'gallery-detail': const GalleryDetailScreen(initialPost: {
      'id': 'detail-demo',
      'image_url': 'https://example.test/demo.png',
      'display_name': '名字很长的创作者爱蜜莉雅',
      'prompt': '慵懒睡衣，真人漫展，电影光影，保留人物细节',
      'like_count': 12345678,
      'favorite_count': 87654321,
      'comment_count': 1234567,
    }),
    'history': const CompendiumScreen(),
    'profile': const ProfileScreen(),
    'collections': const GalleryCollectionsScreen(),
    'login': const LoginScreen(),
    'register': const RegisterScreen(),
    'reset-password': const PasswordResetScreen(),
    'feedback': const FeedbackScreen(),
  }.entries) {
    testWidgets('${entry.key} supports narrow large text and scrolling',
        (tester) async {
      await frontend.mount(tester, entry.value, LongContentGateway(),
          size: const Size(320, 800), scale: 2);
      await capture(tester, frontend.boundary, '${entry.key}-top');
      expect(tester.takeException(), isNull);
      if (entry.key == 'gallery') {
        final sort = tester.renderObject<RenderParagraph>(find.text('最近时间'));
        expect(sort.didExceedMaxLines, isFalse,
            reason: 'The selected sorting rule must remain readable.');
      }
      if (entry.key == 'profile') {
        final name = tester.renderObject<RenderParagraph>(find.text('爱蜜莉雅'));
        final lines = name.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4));
        expect(lines.map((box) => box.top).toSet(), hasLength(1),
            reason: 'Avatar must not split a short display name.');
      }
      final scroll = find.byType(Scrollable).first;
      for (var i = 0; i < 5; i++) {
        await tester.drag(scroll, const Offset(0, -350));
        await settle(tester);
        expect(tester.takeException(), isNull);
      }
      await capture(tester, frontend.boundary, '${entry.key}-bottom');
      if (entry.key == 'profile') {
        await frontend.visible(tester, find.text('个人资料'));
        await tester.tap(find.text('个人资料'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await capture(tester, frontend.boundary, 'profile-details');
        final bind = find.text('绑定邮箱');
        await tester.scrollUntilVisible(bind, 180,
            scrollable: find
                .descendant(
                    of: find.byType(BottomSheet),
                    matching: find.byType(Scrollable))
                .first);
        await settle(tester);
        await tester.ensureVisible(bind);
        await settle(tester);
        await tester.tap(bind);
        await settle(tester);
        final code = find.byWidgetPredicate((widget) =>
            widget is TextField && widget.decoration?.labelText == '验证码');
        expect(tester.getSize(code).width, greaterThanOrEqualTo(200));
        await capture(tester, frontend.boundary, 'bind-email');
        expect(tester.takeException(), isNull);
      } else if (entry.key == 'register' || entry.key == 'reset-password') {
        final code = find.byWidgetPredicate((widget) =>
            widget is TextField && widget.decoration?.labelText == '邮箱验证码');
        await tester.ensureVisible(code);
        expect(tester.getSize(code).width, greaterThanOrEqualTo(200));
        await tester.enterText(code, '123456');
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await settle(tester);
        await tester.ensureVisible(code);
        await settle(tester);
        expect(tester.getBottomLeft(code).dy, lessThanOrEqualTo(520));
        expect(tester.takeException(), isNull);
        await capture(tester, frontend.boundary, '${entry.key}-code-keyboard');
      } else if (entry.key == 'feedback') {
        await tester.tap(find.byType(FloatingActionButton));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await capture(tester, frontend.boundary, 'feedback-compose');
        final content = find.byType(TextField).last;
        await tester.ensureVisible(content);
        await tester.enterText(content, '这里是较长的问题说明，用于检查键盘弹出后的表单布局。');
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await settle(tester);
        await tester.ensureVisible(content);
        await settle(tester);
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final view in ['settings', 'users', 'backups', 'feedback']) {
    testWidgets('Admin $view supports narrow large text', (tester) async {
      await admin.mountAdmin(tester, admin.ManagementGateway(),
          view: view, size: const Size(320, 800), scale: 2);
      expect(tester.takeException(), isNull);
      await capture(tester, admin.boundaryKey, 'admin-$view');
      if (view == 'settings') {
        await admin.openGeneration(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await settle(tester);
        expect(find.widgetWithText(FilledButton, '保存').hitTestable(),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, admin.boundaryKey, 'admin-settings-keyboard');
      } else if (view == 'backups') {
        await tester.tap(find.widgetWithText(FilledButton, '备份设置'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await capture(tester, admin.boundaryKey, 'admin-backup-settings');
      }
    });
  }

  testWidgets('Long account names remain readable', (tester) async {
    await frontend.mount(tester, const ProfileScreen(), LongContentGateway(),
        size: const Size(320, 800), scale: 2);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)));
    container.read(authStateProvider.notifier).state = {
      ...frontend.fixtureUser,
      'username': 'very_long_account_name_without_spaces_123456789',
      'display_name': '名字很长的用户昵称爱蜜莉雅慵懒睡衣真人漫展',
    };
    await settle(tester);
    expect(tester.takeException(), isNull);
    await capture(tester, frontend.boundary, 'profile-long-name');
  });
}
