import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/app_motion.dart';

class DraftPage extends StatefulWidget {
  const DraftPage({super.key, required this.name});
  final String name;

  @override
  State<DraftPage> createState() => DraftPageState();
}

class DraftPageState extends State<DraftPage> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        decoration: InputDecoration(labelText: widget.name),
      );
}

void main() {
  testWidgets('Tab changes keep page geometry fixed on every animation frame',
      (tester) async {
    Future<void> show(int index) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: AppTabStack(index: index, visited: const {
              0,
              1
            }, children: const [
              SizedBox.expand(key: ValueKey('page-0')),
              SizedBox.expand(key: ValueKey('page-1')),
            ]),
          ),
        ));
    await show(0);
    await tester.pumpAndSettle();
    final original = tester.getRect(find.byKey(const ValueKey('page-0')));
    for (final index in [1, 0, 1]) {
      await show(index);
      for (final milliseconds in [0, 16, 40, 100, 220]) {
        await tester.pump(Duration(milliseconds: milliseconds));
        expect(tester.getRect(find.byKey(ValueKey('page-$index'))), original,
            reason: 'Switching tabs must not slide the page or its wallpaper.');
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android predictive back can cancel and commit', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    late MaterialPageRoute<void> detail;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      theme: ThemeData(
        platform: TargetPlatform.android,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: AppAndroidPageTransitionsBuilder(),
        }),
      ),
      home: const Scaffold(body: Text('home')),
    ));
    detail = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail')));
    navigator.currentState!.push(detail);
    await tester.pumpAndSettle();

    Future<void> gesture(String method,
        [Map<String, dynamic>? arguments]) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
      await tester.pump();
    }

    Future<void> start() => gesture('startBackGesture', {
          'touchOffset': <double>[5, 300],
          'progress': 0.0,
          'swipeEdge': 0,
        });
    Future<void> update() => gesture('updateBackGestureProgress', {
          'touchOffset': <double>[100, 300],
          'progress': 0.35,
          'swipeEdge': 0,
        });

    await start();
    expect(detail.popGestureInProgress, isTrue);
    await update();
    expect(detail.animation!.value, closeTo(0.65, 0.01));
    await gesture('cancelBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    expect(detail.popGestureInProgress, isFalse);
    expect(detail.animation!.value, 1);

    await start();
    await update();
    await gesture('commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rapid tab changes retain drafts and pause hidden tickers',
      (tester) async {
    final first = GlobalKey<DraftPageState>();
    final second = GlobalKey<DraftPageState>();
    Future<void> show(int index, Set<int> visited) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppTabStack(index: index, visited: visited, children: [
                DraftPage(key: first, name: 'first'),
                DraftPage(key: second, name: 'second'),
              ]),
            ),
          ),
        );
    await show(0, {0});
    expect(second.currentState, isNull);
    first.currentState!.controller.text = 'unfinished prompt';
    final original = first.currentState;
    await show(1, {0, 1});
    await tester.pump(const Duration(milliseconds: 40));
    expect(TickerMode.valuesOf(first.currentContext!).enabled, isFalse);
    expect(TickerMode.valuesOf(second.currentContext!).enabled, isTrue);
    await show(0, {0, 1});
    await show(1, {0, 1});
    await show(0, {0, 1});
    await tester.pumpAndSettle();
    expect(first.currentState, same(original));
    expect(first.currentState!.controller.text, 'unfinished prompt');
    expect(TickerMode.valuesOf(first.currentContext!).enabled, isTrue);
    expect(TickerMode.valuesOf(second.currentContext!).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion immediately finishes entry, including mid-flight',
      (tester) async {
    Future<void> show(bool reduced, int identity) => tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: AppEntrance(
                identity: identity,
                child: const Text('content'),
              ),
            ),
          ),
        );
    await show(false, 0);
    await tester.pump(const Duration(milliseconds: 40));
    await show(true, 0);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await show(true, 1);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Rebuilding content does not replay its entry animation',
      (tester) async {
    Future<void> show(String value) => tester.pumpWidget(MaterialApp(
          home: AppEntrance(identity: 'same', child: Text(value)),
        ));
    await show('before');
    await tester.pumpAndSettle();
    await show('after');
    expect(find.text('after'), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Reduced motion routes display immediately and can return',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      theme: ThemeData(
        platform: TargetPlatform.android,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: AppAndroidPageTransitionsBuilder(),
        }),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: const Scaffold(body: Text('home')),
    ));
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail'))));
    await tester.pump();
    // Navigator lays out a new route offstage during its first frame.
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('detail'), findsOneWidget);
    expect(find.byType(FadeTransition), findsNothing);
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
