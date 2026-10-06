import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/app_brand.dart';
import 'package:re0/core/stable_form_dialog.dart';

import 'admin_generation_settings_test.dart' show settingField;
import 'admin_management_test.dart' as fixtures;

class EntityGateway extends fixtures.ManagementGateway {
  Object active = 1;
  Map<String, dynamic>? saved;

  Map<String, dynamic> get entity => {
        'id': 'r',
        'name': '普通操作员',
        'description': '管理状态测试',
        'is_active': active,
        'permissions': <String>[],
        'user_count': 1,
      };

  @override
  Future<List<dynamic>> adminRoles() async => [entity];
  @override
  Future<List<dynamic>> adminGroups() async => [entity];
  @override
  Future<List<dynamic>> adminApiKeys() async => [entity];
  @override
  Future<List<dynamic>> adminPermissions() async => [];
  @override
  Future<dynamic> saveAdminRole(
          String? id, Map<String, dynamic> payload) async =>
      saved = payload;
  @override
  Future<dynamic> saveAdminGroup(
          String? id, Map<String, dynamic> payload) async =>
      saved = payload;
  @override
  Future<dynamic> saveAdminApiKey(
          String? id, Map<String, dynamic> payload) async =>
      saved = payload;
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final phase = Platform.environment['RE0_CAPTURE_MOBILE_FIXES'];
  if (phase == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file =
        File('evidence/screenshots/mobile-admin-20261006/$phase/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void expectLabelVisible(WidgetTester tester, String label) {
  final scroll = find.descendant(
      of: find.byType(Dialog), matching: find.byType(SingleChildScrollView));
  final viewport = tester.getRect(scroll);
  final text =
      find.descendant(of: settingField(label), matching: find.text(label));
  final render = tester.renderObject<RenderBox>(text);
  final painted = MatrixUtils.transformRect(
      render.getTransformTo(null), render.paintBounds);
  expect(painted.top, greaterThanOrEqualTo(viewport.top),
      reason:
          'The complete floating label must remain inside the scroll clip.');
  expect(painted.left, greaterThanOrEqualTo(viewport.left));
  expect(painted.right, lessThanOrEqualTo(viewport.right));
  expect(painted.bottom, lessThanOrEqualTo(viewport.bottom));
}

void main() {
  setUpAll(() async {
    if (Platform.environment['RE0_CAPTURE_MOBILE_FIXES'] == null) return;
    for (final family in ['AdminEvidence', 'MaterialIcons']) {
      final loader = FontLoader(family);
      loader.addFont(File(family == 'MaterialIcons'
              ? '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
              : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
          .readAsBytes()
          .then(ByteData.sublistView));
      await loader.load();
    }
  });

  for (final view in ['roles', 'groups', 'apiKeys']) {
    testWidgets('$view displays server flags and preserves disabled edits',
        (tester) async {
      final gateway = EntityGateway();
      await fixtures.mountAdmin(tester, gateway, view: view, extraPermissions: [
        'role.view',
        'role.manage',
        'group.view',
        'group.manage',
        'api_key.view',
        'api_key.manage',
      ]);
      final card =
          find.ancestor(of: find.text('普通操作员'), matching: find.byType(Card));
      for (final value in [1, true, '1', 'true', 0, false, '0', 'false']) {
        gateway.active = value;
        await tester.tap(find.byTooltip('刷新当前页面'));
        await tester.pumpAndSettle();
        final enabled = [1, true, '1', 'true'].contains(value);
        if (value == 1 || value == 0) {
          await capture(tester, fixtures.boundaryKey, '$view-status-$value');
        }
        expect(
            find.descendant(
                of: card, matching: find.text(enabled ? '已启用' : '已停用')),
            findsOneWidget);
        await tester
            .tap(find.descendant(of: card, matching: find.byIcon(Icons.edit)));
        await tester.pumpAndSettle();
        final checkbox = find
            .descendant(
                of: find.byType(Dialog),
                matching: find.byType(CheckboxListTile))
            .last;
        expect(tester.widget<CheckboxListTile>(checkbox).value, enabled);
        await tester.tap(find.widgetWithText(FilledButton, '保存'));
        await tester.pumpAndSettle();
        expect(gateway.saved!['is_active'], enabled,
            reason: 'Editing a name must not enable a disabled entity.');
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [(360.0, 1.0), (320.0, 2.0)]) {
    testWidgets('First admin label remains visible with keyboard at $scenario',
        (tester) async {
      await fixtures.mountAdmin(tester, EntityGateway(),
          view: 'users', size: Size(scenario.$1, 800), scale: scenario.$2);
      await tester.tap(find.byTooltip('编辑用户').first);
      await tester.pumpAndSettle();
      await capture(
          tester, fixtures.boundaryKey, 'user-label-${scenario.$1.toInt()}');
      expectLabelVisible(tester, '用户名');
      final surface = find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first;
      final top = tester.getTopLeft(surface);
      await tester.tap(settingField('用户名'));
      addTearDown(tester.view.resetViewInsets);
      for (final inset in [80.0, 200.0, 280.0, 160.0, 0.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(surface), top);
        expectLabelVisible(tester, '用户名');
      }
      await tester.enterText(settingField('用户名'), 'alice-updated');
      await capture(tester, fixtures.boundaryKey,
          'user-label-focused-${scenario.$1.toInt()}');
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Shared form first label is visible in each theme',
      (tester) async {
    final controller = TextEditingController(text: '已填写的内容');
    addTearDown(controller.dispose);
    for (final brand in AppBrands.all) {
      await tester.pumpWidget(MaterialApp(
        theme: brand.theme,
        home: Scaffold(
            body: StableFormDialog(
          title: const Text('编辑资料'),
          content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: '显示名称')),
          actions: const [TextButton(onPressed: null, child: Text('取消'))],
        )),
      ));
      await tester.pumpAndSettle();
      expectLabelVisible(tester, '显示名称');
      expect(tester.takeException(), isNull);
    }
  });
}
