import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:larg_editor/page/editor/card_tree.dart';
import 'package:larg_editor/page/editor/desktop_workbench.dart';
import 'package:larg_editor/page/editor/editor_models.dart';

EditablePack _pack() {
  final pack = EditablePack.empty();
  pack.manifest.gameName = '测试剧本';
  final stage = pack.stages.single;
  stage.id = 's1';
  stage.lines
    ..clear()
    ..add(EditableLine(id: 'l1', type: 'narration', text: '第一句台词'))
    ..add(EditableLine(id: 'l2', type: 'dialogue', speaker: '老板', text: '第二句'));
  stage.checkpoints
    ..clear()
    ..add(EditableCheckpoint(text: '去下一关', next: 's1'));
  return pack;
}

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('卡片树：关卡卡片与台词内容都可见', (tester) async {
    final pack = _pack();
    await tester.pumpWidget(
      _wrap(
        CardTree(
          pack: pack,
          selected: const CardSelection(0),
          onSelect: (_) {},
          onAddStage: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 关卡标题可见
    expect(find.text('s1'), findsWidgets);
    // 台词正文可见（这是"看不见实际卡片里的内容"的回归）
    expect(find.text('第一句台词'), findsOneWidget);
    expect(find.textContaining('第二句'), findsOneWidget);
    // 分支文案可见
    expect(find.text('去下一关'), findsOneWidget);
  });

  testWidgets('卡片树：展开/折叠不报错', (tester) async {
    final pack = _pack();
    await tester.pumpWidget(
      _wrap(
        CardTree(
          pack: pack,
          selected: null,
          onSelect: (_) {},
          onAddStage: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('第一句台词'), findsNothing);
  });

  testWidgets('工作台 1280x720：三区齐全且不溢出', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final pack = _pack();
    await tester.pumpWidget(
      _wrap(
        DesktopWorkbench(
          pack: pack,
          callbacks: WorkbenchCallbacks(
            onUser: () {},
            onSettings: () {},
            onNew: () {},
            onOpen: () {},
            onSave: () {},
            onUndo: () {},
            onRedo: () {},
            onDoctor: () {},
            onScript: () {},
            onExport: () {},
            onExportWeb: () {},
            onImport: () {},
            onRecent: () {},
            onClear: () {},
            onRestore: () {},
          ),
          section: WorkbenchSection.stage,
          onSectionChanged: (_) {},
          selectedStage: 0,
          selectedLine: null,
          selectedCheckpoint: null,
          onSelectStage: (_) {},
          onSelectLine: (_) {},
          contentBuilder: (_) => CardTree(
            pack: pack,
            selected: const CardSelection(0),
            onSelect: (_) {},
            onAddStage: () {},
          ),
          inspectorBuilder: (s, l, c) => const Text('检查器'),
          previewBuilder: (s, l) =>
              const ColoredBox(color: Colors.black, child: Text('预览')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 溢出会被 tester 记录成异常
    expect(tester.takeException(), isNull);
    expect(find.text('检查器'), findsOneWidget);
    expect(find.text('预览'), findsOneWidget);
    expect(find.text('第一句台词'), findsOneWidget);
  });
}
