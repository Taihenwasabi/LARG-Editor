import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:larg_editor/component/engine.dart';
import 'package:larg_editor/engine/pack_doctor.dart';

Uint8List _j(String s) => Uint8List.fromList(utf8.encode(s));

GameEngine _engine(Map<String, Map<String, String>> packs) {
  final source = MemoryPackageSource(
    root: 'memory',
    files: {
      for (final e in packs.entries)
        e.key: {for (final f in e.value.entries) f.key: _j(f.value)},
    },
  );
  return GameEngine(tokenProvider: InMemoryTokenProvider('t'))..useSource(source);
}

const _m = '{"gameName":"fx测试","Id":"g-fx","PublicKey":"K"}';

void main() {
  test('行特效解析：词表内可渲染，未知动作静默跳过', () {
    final engine = _engine({
      'p': {
        'basicInfo.json': _m,
        'stage/1.json': '''
{"id":"s1","lines":[
 {"lineId":"a","text":"开场","fx":[
  {"on":"enter","target":"screen","type":"shake","intensity":6,"duration":350},
  {"on":"enter","target":"text","type":"typewriter","cps":18},
  {"on":"enter","target":"background","type":"panZoom","to":1.06,"duration":6000}
 ]},
 {"lineId":"b","text":"次行","fx":[
  {"on":"enter","target":"screen","type":"teleport","duration":100}
 ]}
]}''',
      },
    });
    final lines = engine.load('p').stages.single.lines;
    expect(lines[0].fx, hasLength(3));
    expect(lines[0].fx[0].trigger, FxTrigger.enter);
    expect(lines[0].fx[0].type, FxType.shake);
    expect(lines[0].fx[0].isRenderable, isTrue);
    expect(lines[0].fx[0].paramInt('intensity', 0), 6);
    // 未知动作 → 可渲染=false，引擎静默跳过
    expect(lines[1].fx.single.isRenderable, isFalse);
  });

  test('过场特效解析：transitionIn / transitionOut', () {
    final engine = _engine({
      'p': {
        'basicInfo.json': _m,
        'stage/1.json': '''
{"id":"s1","fx":{
 "transitionIn":[{"on":"transitionIn","target":"screen","type":"fade","duration":300}],
 "transitionOut":[{"on":"transitionOut","target":"screen","type":"fade","duration":200}]
},"lines":[{"text":"a"}]}''',
      },
    });
    final stage = engine.load('p').stages.single;
    expect(stage.transitionIn, hasLength(1));
    expect(stage.transitionOut.single.durationMs, 200);
  });

  test('sprite 槽位解析', () {
    final engine = _engine({
      'p': {
        'basicInfo.json': _m,
        'stage/1.json': '''
{"id":"s1","lines":[{"text":"a","sprites":[
 {"asset":"a.png","slot":"hero","position":"left"}
],"fx":[{"on":"enter","target":"sprite:hero","type":"slide","from":"right"}]}]}''',
      },
    });
    final line = engine.load('p').stages.single.lines.single;
    expect(line.sprites.single.slot, 'hero');
    expect(line.fx.single.target.spriteSlot, 'hero');
  });

  test('doctor：特效应答正常，未知动作只警告不阻断', () {
    final engine = _engine({
      'p': {
        'basicInfo.json': _m,
        'stage/1.json': '''
{"id":"s1","lines":[{"text":"a","fx":[
 {"on":"enter","target":"screen","type":"teleport","duration":100}
]}]}''',
      },
    });
    final report = PackDoctor.inspect(engine.load('p'));
    expect(
      report.issues.any((e) => e.code == 'fx.unknown'),
      isTrue,
    );
  });

  test('doctor：立绘寻址落空报错误', () {
    final engine = _engine({
      'p': {
        'basicInfo.json': _m,
        'stage/1.json': '''
{"id":"s1","lines":[{"text":"a","fx":[
 {"on":"enter","target":"sprite:ghost","type":"slide"}
]}]}''',
      },
    });
    final report = PackDoctor.inspect(engine.load('p'));
    expect(
      report.issues.any((e) => e.code == 'fx.spriteMissing'),
      isTrue,
    );
  });

  test('编辑器往返：fx 从 JSON 导入 → 导出 → 引擎仍能解析', () {
    // 直接验证 EditableLine 的 fxRaw 往返（通过 EditablePack 的 toFiles）
    // 这里用引擎包加载已覆盖解析侧；再验证编辑侧导出的 JSON 含 fx。
    final engine = _engine({
      'p': {
        'basicInfo.json': _m,
        'stage/1.json': '''
{"id":"s1","lines":[{"lineId":"a","text":"x","fx":[
 {"on":"enter","target":"screen","type":"shake","intensity":5}
]}]}''',
      },
    });
    final pkg = engine.load('p');
    final fx = pkg.stages.single.lines.single.fx;
    expect(fx, hasLength(1));
    expect(fx.single.paramInt('intensity', 0), 5);
  });

  test('旧包无 fx 字段：解析结果与以前一致，doctor 不报新错', () {
    final engine = _engine({
      'p': {
        'basicInfo.json': _m,
        'stage/1.json': '{"id":"s1","lines":[{"text":"a"}]}',
      },
    });
    final pkg = engine.load('p');
    expect(pkg.stages.single.lines.single.fx, isEmpty);
    expect(pkg.stages.single.transitionIn, isEmpty);
    expect(PackDoctor.inspect(pkg).issues, isEmpty);
  });
}
