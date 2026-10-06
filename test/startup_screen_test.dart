import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/api_error.dart';
import 'package:re0/core/app_brand.dart';
import 'package:re0/core/providers.dart';
import 'package:re0/core/startup_screen.dart';
import 'package:re0/features/auth/login_screen.dart';
import 'package:re0/features/home/home_screen.dart';
import 'package:re0/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'frontend_management_test.dart' as fixture;

class StartupGateway extends fixture.FrontendGateway {
  final ready = Completer<void>();
  bool signedIn = false;
  bool forceUpdate = false;
  int clearedSessions = 0;

  @override
  Future<void> init(String url) async {}

  @override
  Future<Map<String, dynamic>> bootstrap() async {
    await ready.future;
    return {'force_app_update_enabled': forceUpdate};
  }

  @override
  Future<Map<String, dynamic>> checkAuth() async {
    if (!signedIn) throw const GatewayException('请登录', statusCode: 401);
    return fixture.fixtureUser;
  }

  @override
  Future<void> clearLocalSession() async => clearedSessions++;
}

Future<void> mountStartup(WidgetTester tester, StartupGateway gateway) async {
  SharedPreferences.setMockInitialValues({'active_brand': 'genshin'});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      gatewayClientProvider.overrideWithValue(gateway),
      imageCacheProvider.overrideWithValue(fixture.FixtureImageCache()),
      imageRequestResumeProvider.overrideWith((ref) async {}),
    ],
    child: const Re0App(),
  ));
  await tester.pump();
}

void main() {
  testWidgets('Slow startup shows saved theme, then opens login immediately',
      (tester) async {
    final gateway = StartupGateway();
    await mountStartup(tester, gateway);
    expect(find.byType(StartupScreen), findsOneWidget);
    expect(find.text(AppBrands.genshin.appTitle), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(LoginScreen), findsNothing);
    gateway.ready.complete();
    await tester.pumpAndSettle();
    expect(find.byType(StartupScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(gateway.clearedSessions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saved login proceeds from startup to home', (tester) async {
    final gateway = StartupGateway()..signedIn = true;
    await mountStartup(tester, gateway);
    expect(find.byType(StartupScreen), findsOneWidget);
    gateway.ready.complete();
    await tester.pumpAndSettle();
    expect(find.byType(StartupScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(gateway.clearedSessions, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Startup preserves required update gate', (tester) async {
    final gateway = StartupGateway()
      ..signedIn = true
      ..forceUpdate = true;
    await mountStartup(tester, gateway);
    gateway.ready.complete();
    await tester.pumpAndSettle();
    expect(find.byType(StartupScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('下载安装'), findsOneWidget);
    expect(gateway.updateReads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion startup settles on a short, large-text screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'active_brand': 'botw'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        theme: AppBrands.botw.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: const StartupScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.ensureVisible(find.text('正在准备…'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
