import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:larg_editor/component/engine.dart';
import 'package:larg_editor/engine/package_io.dart';
import 'package:larg_editor/engine/pack_doctor.dart';
import 'package:larg_editor/page/editor/editor_models.dart';

/// 端到端契约测试：编辑 → 导出 → 导入 → 自检 → 试玩数据一致。
///
/// 这是「打开包 → 改台词 → 试玩 → 导出往返无损」的可验证核心。
/// 走真实的包格式，不靠点 UI。
void main() {
  test('改台词后导出，再导入，台词是改后的；自检通过', () {
    // 1. 建一个最小可玩的包（模拟用户「我写了剧本」）
    final pack = EditablePack.empty();
    pack.manifest
      ..gameName = '剧本游测试'
      ..id = 'g-story-0001'
      ..introduction = '一段测试剧本';
    final stage = pack.stages.single;
    stage.lines
      ..clear()
      ..add(
        EditableLine(
          id: 'start',
          type: 'narration',
          text: '原始台词',
        ),
      );

    // 2. 用户改台词（编辑器里改的就是 EditablePack 的内存数据）
    stage.lines.first.text = '改后的台词：湖边重逢';

    // 3. 导出 zip（走引擎的打包与安全规则）
    final entries = pack.toArchiveEntries();
    final zip = packToZipBytes(entries, rootName: pack.name);
    expect(zip.isNotEmpty, isTrue);

    // 4. 再导入（走引擎的解包与安全规则）
    final reopened = EditablePack.fromZip(zip, root: pack.name);
    expect(reopened.stages, isNotEmpty);

    // 5. 断言：改后的台词还在，往返无损
    expect(
      reopened.stages.first.lines.first.text,
      '改后的台词：湖边重逢',
    );

    // 6. 用引擎加载这个包 + doctor 自检，确认它真能玩
    final files = unpackZipBytes(zip);
    final engine = GameEngine(tokenProvider: InMemoryTokenProvider('e2e'))
      ..useSource(MemoryPackageSource(root: 'memory', files: {'pack': files}));
    final loaded = engine.load(engine.listPackages().single);
    expect(loaded.stages, isNotEmpty);
    expect(loaded.stages.first.lines.first.text, '改后的台词：湖边重逢');
    final report = PackDoctor.inspect(loaded);
    expect(report.issues, isEmpty, reason: report.summary);
  });

  test('带分支+校验+物品的包，往返后结构与引用不丢', () {
    final pack = EditablePack.empty();
    pack.manifest
      ..gameName = '带分支的剧本'
      ..id = 'g-story-0002';
    final s1 = pack.stages.single;
    s1.id = 's1';
    s1.lines
      ..clear()
      ..add(EditableLine(id: 'l1', type: 'narration', text: '第一幕'));
    s1.checkpoints
      ..clear()
      ..add(
        EditableCheckpoint(
          text: '选A',
          next: 's2',
          reward: 10,
          grant: const {'gem': 1},
        ),
      );
    // 补第二关、校验题、物品
    pack.stages.add(
      EditableStage(
        fileName: '2end.json',
        id: 's2',
        lines: [EditableLine(id: 'l2', type: 'narration', text: '结局')],
      ),
    );
    pack.items.add(
      EditableStoryItem(id: 'gem', name: '宝石', initial: 0),
    );

    final zip = packToZipBytes(
      pack.toArchiveEntries(),
      rootName: pack.name,
    );
    final reopened = EditablePack.fromZip(zip, root: pack.name);

    expect(reopened.stages.length, 2);
    expect(reopened.items.map((e) => e.id), contains('gem'));
    expect(reopened.stages.first.checkpoints.first.grant['gem'], 1);
    expect(reopened.stages.first.checkpoints.first.next, 's2');

    final files = unpackZipBytes(zip);
    final engine = GameEngine(tokenProvider: InMemoryTokenProvider('e2e'))
      ..useSource(MemoryPackageSource(root: 'memory', files: {'pack': files}));
    final loaded = engine.load(engine.listPackages().single);
    final report = PackDoctor.inspect(loaded);
    expect(report.issues, isEmpty, reason: report.summary);
  });

  test('恶意 zip 在「导入」这一步就被拒绝，不会进编辑器', () {
    // 构造一个含 .. 的 zip
    final archive = Archive();
    archive.addFile(ArchiveFile('pack/basicInfo.json', 2, Uint8List.fromList([123, 125])));
    archive.addFile(ArchiveFile('pack/../../evil.txt', 1, Uint8List.fromList([88])));
    final bytes = ZipEncoder().encode(archive)!;
    final zip = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    expect(
      () => EditablePack.fromZip(zip),
      throwsA(isA<PackageFormatException>()),
    );
  });
}
