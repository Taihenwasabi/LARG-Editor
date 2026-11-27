import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/index.dart';
import 'package:larg_editor/store/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: EditorPage()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await I18n.instance.init('zh-CN');
    await AppSettings.instance.load();
  });

  testWidgets('新建包默认有一句台词，卡片可见', (tester) async {
    await _pumpEditor(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('故事从这里开始。'), findsWidgets);
  });

  testWidgets('加台词后能撤销、再重做', (tester) async {
    await _pumpEditor(tester);

    expect(find.text('故事从这里开始。'), findsWidgets);
    expect(find.text('加一句台词'), findsOneWidget);

    await tester.tap(find.text('加一句台词'));
    await tester.pumpAndSettle();

    final undoBtn = find.byTooltip('撤销');
    final redoBtn = find.byTooltip('重做');
    expect(undoBtn, findsOneWidget);

    await tester.tap(undoBtn);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(redoBtn);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除关卡后能撤销回来', (tester) async {
    await _pumpEditor(tester);

    await tester.tap(find.text('删掉这关'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('故事从这里开始。'), findsWidgets);
  });
}

