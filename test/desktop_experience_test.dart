import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/app_update_service.dart';
import 'package:re0/core/creation_workbench.dart';
import 'package:re0/core/creation_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Draft saves on disposal and stays scoped to account and creation mode',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = TextEditingController();
    final draft =
        CreationDraft(prefs, 'alice', 'generate', {'prompt': controller});
    controller.text = '有特色的主题与风格';
    draft.dispose();
    final restored = TextEditingController();
    final other = TextEditingController();
    final anotherMode = TextEditingController();
    final restore =
        CreationDraft(prefs, 'alice', 'generate', {'prompt': restored});
    final separate = CreationDraft(prefs, 'bob', 'generate', {'prompt': other});
    final edit = CreationDraft(prefs, 'alice', 'edit', {'prompt': anotherMode});
    expect(restored.text, controller.text);
    expect(other.text, isEmpty);
    expect(anotherMode.text, isEmpty);
    restore.dispose();
    separate.dispose();
    edit.dispose();
    controller.dispose();
    restored.dispose();
    other.dispose();
    anotherMode.dispose();
  });
  AppUpdateService service() => AppUpdateService(
      repository: 'test/re0',
      assetNamePrefix: 'RE0',
      appId: 're0',
      appName: 'RE0',
      packageName: 'com.dq52099.re0',
      currentVersionName: '1.2.40',
      currentVersionCode: 10240,
      currentReleaseTag: 'v1.2.40',
      platform: TargetPlatform.windows);
  Map<String, dynamic> manifest() => {
        'platform': 'windows-x64',
        'version_code': 10241,
        'version_name': '1.2.41',
        'download_url':
            'https://work.6688667.xyz/boxying-desktop/RE0-1.2.41-setup.exe',
        'sha256': List.filled(64, 'a').join(),
        'file_size': 5000
      };

  test(
      'Windows update channel accepts only its own installer and compares build numbers',
      () {
    final updater = service();
    expect(updater.fromWindowsManifest(manifest()).available, isTrue);
    expect(
        updater.fromWindowsManifest(
            {...manifest(), 'version_code': 10240}).available,
        isFalse);
    expect(
        updater.fromWindowsManifest(
            {...manifest(), 'version_code': 10239}).available,
        isFalse);
    for (final invalid in [
      {...manifest(), 'platform': 'android'},
      {
        ...manifest(),
        'download_url': 'https://work.6688667.xyz/boxying-mobile/RE0.apk'
      },
      {
        ...manifest(),
        'download_url': 'https://other.test/boxying-desktop/RE0.exe'
      },
      {
        ...manifest(),
        'download_url': 'http://work.6688667.xyz/boxying-desktop/RE0.exe'
      },
      {...manifest(), 'sha256': ''},
    ]) {
      expect(() => updater.fromWindowsManifest(invalid), throwsStateError);
    }
  });

  testWidgets('Resizing the workspace preserves draft and expanded assistant',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var submissions = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CreationWorkbench(
      onSubmit: () => submissions++,
      inputs: const [
        TextField(key: ValueKey('draft')),
        ExpansionTile(title: Text('助手'), children: [Text('已展开的助手')]),
        SizedBox(height: 1000)
      ],
      results: const [Text('创作结果'), SizedBox(height: 1000)],
    ))));
    await tester.enterText(find.byKey(const ValueKey('draft')), '保留桌面草稿');
    await tester.tap(find.text('助手'));
    await tester.pumpAndSettle();
    final outputBefore = tester.getTopLeft(find.text('创作结果'));
    await tester.drag(find.byType(TextField), const Offset(0, -140));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('创作结果')), outputBefore,
        reason: 'Result pane must not scroll with the form.');
    await tester.binding.setSurfaceSize(const Size(720, 900));
    await tester.pumpAndSettle();
    expect(find.text('保留桌面草稿'), findsOneWidget);
    expect(find.text('已展开的助手'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.tap(find.byType(TextField));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(submissions, 1);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.value = const TextEditingValue(
        text: 'zhong',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(submissions, 1,
        reason: 'Do not submit while a Chinese IME is composing.');
    expect(tester.takeException(), isNull);
  });
}
