import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/gateway_client.dart';
import 'package:re0/core/providers.dart';
import 'package:re0/features/admin/admin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsGateway extends GatewayClient {
  final values = <String, dynamic>{
    'provider_base_url': 'https://primary.example/v1',
    'provider_primary_enabled': 'true',
    'provider_model': 'gpt-image-2',
    'provider_image_profile': 'gpt-image-2',
    'provider_backup_base_url': 'https://backup.example/v1',
    'provider_backup_enabled': 'false',
    'provider_backup_model': 'gpt-image-2.5',
    'provider_backup_image_profile': 'gpt-image-2',
    'provider_active_slot': 'primary',
    'provider_healthcheck_enabled': 'false',
    'provider_async_enabled': 'false',
    'provider_backup_async_enabled': 'true',
    'general_provider_enabled': 'false',
    'provider_timeout_seconds': '900',
  };
  Map<String, dynamic>? submitted;
  int reads = 0;

  @override
  Future<Map<String, dynamic>> adminSystemSettings() async {
    reads += 1;
    return {
      'settings': [
        for (final entry in values.entries)
          {'key': entry.key, 'value': entry.value, 'category': '生成线路'},
      ],
      'runtime_status': {
        'provider_active_slot': values['provider_active_slot'],
        'provider_model': values['provider_model'],
      },
    };
  }

  @override
  Future<Map<String, dynamic>> saveAdminSystemSettings(
      Map<String, dynamic> payload) async {
    submitted = Map.of(payload);
    values.addAll(payload);
    return adminSystemSettings();
  }
}

Finder settingField(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label);

void main() {
  testWidgets('APK saves backup controls and reads persisted values back',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gateway = SettingsGateway();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        gatewayClientProvider.overrideWithValue(gateway),
        authStateProvider.overrideWith((ref) => {
              'permissions': ['settings.view', 'settings.manage'],
            }),
      ],
      child: const MaterialApp(home: AdminScreen(initialView: 'settings')),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('编辑生成线路'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑生成线路'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(settingField('主用生图模型')).controller!.text,
        'gpt-image-2');
    expect(tester.widget<TextField>(settingField('备用生图模型')).controller!.text,
        'gpt-image-2.5');
    gateway.values['provider_model'] = 'external-primary-change';

    final backupSwitch = find.widgetWithText(SwitchListTile, '启用备用生图服务');
    await tester.ensureVisible(backupSwitch);
    await tester.pumpAndSettle();
    await tester.tap(backupSwitch);
    await tester.pumpAndSettle();
    await tester.ensureVisible(settingField('备用生图模型'));
    await tester.pumpAndSettle();
    await tester.enterText(settingField('备用生图模型'), 'custom-image-model');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(gateway.submitted, {
      'provider_backup_enabled': true,
      'provider_backup_model': 'custom-image-model',
    });
    expect(gateway.values['provider_model'], 'external-primary-change');
    expect(gateway.values['provider_healthcheck_enabled'], 'false');
    expect(gateway.values['provider_backup_image_profile'], 'gpt-image-2');
    expect(find.textContaining('图片档位'), findsNothing);

    await tester.ensureVisible(find.byTooltip('编辑生成线路'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑生成线路'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(backupSwitch).value, isTrue);
    expect(tester.widget<TextField>(settingField('主用生图模型')).controller!.text,
        'external-primary-change');
    expect(tester.widget<TextField>(settingField('备用生图模型')).controller!.text,
        'custom-image-model');
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    final reads = gateway.reads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(gateway.reads, greaterThan(reads));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
