import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/api_error.dart';
import 'package:re0/core/providers.dart';
import 'package:re0/features/admin/admin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_generation_settings_test.dart' show SettingsGateway, settingField;

class ManagementGateway extends SettingsGateway {
  bool failSave = false;
  Completer<void>? gate;
  int saves = 0;
  int userReads = 0;
  int feedbackReads = 0;
  Map<String, dynamic>? userPayload;
  ManagementGateway() {
    values.addAll({
      'ui_title': '从零开始生图',
      'vip_image_quota_multiplier': '0.5',
      'registration_email_required': 'true',
      'local_backup_enabled': 'true',
      'local_backup_interval_minutes': '3600',
      'local_backup_retention_days': '3',
      'openlist_backup_sync_cleanup_enabled': 'false',
      'openlist_backup_sync_retention_days': '3',
      'openlist_backup_upload_timeout_minutes': '60',
    });
  }
  @override
  Future<Map<String, dynamic>> adminSystemSettings() async {
    final data = await super.adminSystemSettings();
    data['settings'] = [
      for (final entry in values.entries)
        {'key': entry.key, 'value': entry.value},
      {'key': 'unfamiliar_server_field', 'value': 'internal'},
    ];
    data['runtime_status'] = {
      'provider_requested_slot': 'primary',
      'provider_active_slot': 'primary',
      'provider_configured': true,
      'provider_base_url': values['provider_base_url'],
      'provider_model': values['provider_model'],
      'provider_timeout_seconds': 900,
      'provider_healthcheck_enabled': false,
      'general_provider_enabled': false,
      'provider_image_profile': 'gpt-image-2',
      'local_backup_enabled': true,
      'openlist_backup_sync_cleanup_enabled': false,
      'opaque_runtime_field': 'internal',
    };
    return data;
  }

  @override
  Future<Map<String, dynamic>> saveAdminSystemSettings(
      Map<String, dynamic> payload) async {
    saves++;
    if (gate != null) await gate!.future;
    if (failSave) throw GatewayException('服务器暂时不可用，请重试');
    return super.saveAdminSystemSettings(payload);
  }

  @override
  Future<Map<String, dynamic>> getAdminFeedback(
      {String? type,
      String? category,
      String? status,
      String? keyword,
      DateTime? startAt,
      DateTime? endAt,
      int page = 1,
      int pageSize = 30}) async {
    feedbackReads++;
    return {'items': [], 'total': 0, 'page': 1, 'page_size': 30};
  }

  @override
  Future<Map<String, dynamic>> adminLocalBackups() async => {'items': []};
  @override
  Future<Map<String, dynamic>> adminOverview() async => {'user_count': 2};
  @override
  Future<List<dynamic>> adminUsers() async {
    userReads++;
    return [
      {
        'id': 'one',
        'username': 'alice',
        'display_name': '爱蜜莉雅',
        'email': 'alice@163.com',
        'role_id': 'r',
        'group_id': 'g',
        'is_active': true,
        'role_name': '管理员',
        'group_name': 'VIP'
      },
      {
        'id': 'two',
        'username': 'bob',
        'display_name': '雷姆',
        'email': 'bob@163.com',
        'role_id': 'r',
        'group_id': 'g',
        'is_active': false,
        'role_name': '用户',
        'group_name': '普通用户'
      },
    ];
  }

  @override
  Future<List<dynamic>> adminGroups() async => [
        {'id': 'g', 'name': 'VIP'}
      ];
  @override
  Future<List<dynamic>> adminRoles() async => [
        {'id': 'r', 'name': '管理员'}
      ];
  @override
  Future<dynamic> saveAdminUser(
      String? id, Map<String, dynamic> payload) async {
    userPayload = payload;
    return payload;
  }
}

final boundaryKey = GlobalKey();
Future<void> mountAdmin(WidgetTester tester, ManagementGateway gateway,
    {String view = 'settings',
    Size size = const Size(430, 900),
    double scale = 1,
    List<String> extraPermissions = const [],
    ThemeData? theme,
    bool configureView = true}) async {
  if (configureView) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  addTearDown(() async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          gatewayClientProvider.overrideWithValue(gateway),
          authStateProvider.overrideWith((ref) => {
                'is_admin': true,
                'id': 'admin',
                'permissions': [
                  'settings.view',
                  'settings.manage',
                  'user.view',
                  'user.manage',
                  'feedback.view',
                  ...extraPermissions,
                ]
              }),
        ],
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme ??
                ThemeData(
                    useMaterial3: true,
                    fontFamily: 'AdminEvidence',
                    colorScheme: ColorScheme.fromSeed(
                        seedColor: const Color(0xff7957b4))),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: AdminScreen(initialView: view)),
      )));
  await tester.pumpAndSettle();
}

Future<void> visible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 300,
        scrollable: find
            .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable))
            .first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> openGeneration(WidgetTester tester) async {
  final edit = find.byTooltip('编辑生成线路');
  await visible(tester, edit);
  await tester.tap(edit);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['RE0_CAPTURE_ADMIN'] != '1') return;
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('evidence/screenshots/admin-redesign-20261004/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void adminTestWidgets(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}

void main() {
  setUpAll(() async {
    if (Platform.environment['RE0_CAPTURE_ADMIN'] == '1') {
      final loader = FontLoader('AdminEvidence');
      loader.addFont(
          File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
              .readAsBytes()
              .then((data) => ByteData.sublistView(data)));
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(File(
              '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then((data) => ByteData.sublistView(data)));
      await icons.load();
    }
  });
  adminTestWidgets(
      'Settings search and runtime use readable fields without refetching',
      (tester) async {
    final gateway = ManagementGateway();
    await mountAdmin(tester, gateway);
    final reads = gateway.reads;
    expect(find.text('实际生图模型'), findsOneWidget);
    expect(find.textContaining('provider_image_profile'), findsNothing);
    expect(find.textContaining('opaque_runtime_field'), findsNothing);
    await capture(tester, 'settings-phone');
    await tester.enterText(find.byType(TextField).first, '注册');
    await tester.pumpAndSettle();
    expect(find.text('基础设置'), findsOneWidget);
    expect(find.byTooltip('编辑生成线路'), findsNothing);
    expect(gateway.reads, reads);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(gateway.reads, reads);
    expect(tester.takeException(), isNull);
  });
  adminTestWidgets(
      'Invalid timeout and failed saves retain edits and allow retry',
      (tester) async {
    final gateway = ManagementGateway();
    await mountAdmin(tester, gateway);
    await openGeneration(tester);
    expect(find.textContaining('图片档位'), findsNothing);
    await capture(tester, 'generation-dialog-phone');
    await visible(tester, settingField('生成等待上限'));
    await tester.enterText(settingField('生成等待上限'), 'oops');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('生成等待上限应为'), findsOneWidget);
    expect(gateway.saves, 0);
    await tester.enterText(settingField('生成等待上限'), '1200');
    gateway.failSave = true;
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('服务器暂时不可用'), findsOneWidget);
    expect(tester.widget<TextField>(settingField('生成等待上限')).controller!.text,
        '1200');
    gateway.failSave = false;
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(gateway.submitted, {'provider_timeout_seconds': 1200});
    expect(find.byType(Dialog), findsNothing);
    expect(gateway.values['provider_backup_image_profile'], 'gpt-image-2');
    expect(gateway.values['provider_healthcheck_enabled'], 'false');
    expect(tester.takeException(), isNull);
  });
  adminTestWidgets('In-flight save disables resubmission and back navigation',
      (tester) async {
    final gateway = ManagementGateway();
    await mountAdmin(tester, gateway);
    await openGeneration(tester);
    await tester.enterText(settingField('主用生图模型'), 'gpt-image-3');
    gateway.gate = Completer<void>();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, '保存中…'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存中…'))
            .onPressed,
        isNull);
    expect(gateway.saves, 1);
    gateway.gate!.complete();
    await tester.pumpAndSettle();
    expect(gateway.saves, 1);
    expect(find.byType(Dialog), findsNothing);
  });
  adminTestWidgets(
      'Backup controls preserve concurrent changes and cloud retention',
      (tester) async {
    final gateway = ManagementGateway();
    await mountAdmin(tester, gateway, view: 'backups');
    await tester.tap(find.widgetWithText(FilledButton, '备份设置'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    gateway.values['provider_model'] = 'other-client-model';
    await visible(tester, settingField('本地备份保留天数'));
    await tester.enterText(settingField('本地备份保留天数'), '4');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(gateway.submitted, {'local_backup_retention_days': 4});
    expect(gateway.values['local_backup_interval_minutes'], '3600');
    expect(gateway.values['openlist_backup_sync_cleanup_enabled'], 'false');
    expect(gateway.values['provider_model'], 'other-client-model');
    await tester.tap(find.widgetWithText(FilledButton, '备份设置'));
    await tester.pumpAndSettle();
    await visible(
        tester, find.widgetWithText(ExpansionTile, 'Google Drive 同步'));
    await tester.tap(find.widgetWithText(ExpansionTile, 'Google Drive 同步'));
    await tester.pumpAndSettle();
    await visible(tester, settingField('Google 服务账号 JSON'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  adminTestWidgets(
      'User search preserves bound email and removes ineffective password input',
      (tester) async {
    final gateway = ManagementGateway();
    await mountAdmin(tester, gateway, view: 'users');
    await capture(tester, 'users-phone');
    await tester.enterText(find.byType(TextField).first, 'alice@163.com');
    await tester.pumpAndSettle();
    expect(find.textContaining('alice)'), findsOneWidget);
    expect(find.textContaining('bob)'), findsNothing);
    expect(gateway.userReads, 1);
    await tester.tap(find.byTooltip('编辑用户').first);
    await tester.pumpAndSettle();
    expect(settingField('密码留空不修改'), findsNothing);
    expect(tester.widget<TextField>(settingField('绑定邮箱（可选）')).controller!.text,
        'alice@163.com');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(gateway.userPayload!['email'], 'alice@163.com');
    expect(gateway.userPayload!.containsKey('password'), isFalse);
    expect(tester.takeException(), isNull);
  });
  adminTestWidgets('Global refresh also reloads the feedback panel',
      (tester) async {
    final gateway = ManagementGateway();
    await mountAdmin(tester, gateway, view: 'feedback');
    expect(gateway.feedbackReads, 1);
    await tester.tap(find.byTooltip('刷新当前页面'));
    await tester.pumpAndSettle();
    expect(gateway.feedbackReads, 2);
    expect(tester.takeException(), isNull);
  });
  for (final scenario in [
    ('small-large-text', const Size(360, 800), 1.4),
    ('tablet', const Size(1000, 1000), 1.0),
  ]) {
    adminTestWidgets(
        'Admin settings layout supports ${scenario.$1} and keyboard',
        (tester) async {
      final gateway = ManagementGateway();
      await mountAdmin(tester, gateway, size: scenario.$2, scale: scenario.$3);
      await capture(tester, 'settings-${scenario.$1}');
      expect(tester.takeException(), isNull);
      await openGeneration(tester);
      await capture(tester, 'dialog-${scenario.$1}');
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, '保存').hitTestable(),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
    });
  }
}
