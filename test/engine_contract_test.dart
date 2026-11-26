import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:larg_editor/component/engine.dart';
import 'package:larg_editor/model/check_ai_config.dart';
import 'package:larg_editor/model/game_item.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

MemoryPackageSource _source(Map<String, Map<String, String>> packs) {
  return MemoryPackageSource(
    root: 'memory',
    files: {
      for (final entry in packs.entries)
        entry.key: {
          for (final file in entry.value.entries)
            file.key: _bytes(file.value),
        },
    },
  );
}

GameEngine _engine(MemoryPackageSource source) =>
    GameEngine(tokenProvider: InMemoryTokenProvider('t'))..useSource(source);

const _manifest = '''
{
  "gameName": "契约测试包",
  "Id": "g-test-0001",
  "official": "no",
  "Introduction": "用于校验包格式契约。",
  "price": "0",
  "createTime": "2026.11.27",
  "ageAppropriateness": "12+",
  "PublicKey": "TEST-PUBKEY-0001",
  "artStyle": "test",
  "points": "测试币",
  "map": "assets/picture/map.png",
  "buttonCoordinates": [{"id": 1, "x": 320, "y": 640}]
}
''';

void main() {
  group('basicInfo.json', () {
    test('字段按契约映射，兼容大小写与别名', () {
      final engine = _engine(
        _source({
          'p': {'basicInfo.json': _manifest},
        }),
      );
      final pkg = engine.load('p');
      final m = pkg.manifest;

      expect(m.gameName, '契约测试包');
      expect(m.id, 'g-test-0001');
      expect(m.isOfficial, isFalse);
      expect(m.introduction, '用于校验包格式契约。');
      expect(m.price, '0');
      expect(m.createTime, '2026.11.27');
      expect(m.ageAppropriateness, '12+');
      expect(m.publicKey, 'TEST-PUBKEY-0001');
      expect(m.artStyle, 'test');
      expect(m.points, '测试币');
      expect(m.mapImage, 'assets/picture/map.png');
      expect(m.buttonCoordinates.single.id, 1);
      expect(m.buttonCoordinates.single.x, 320);
    });

    test('可选字段缺省值符合契约', () {
      final engine = _engine(
        _source({
          'p': {'basicInfo.json': '{"gameName":"最简包"}'},
        }),
      );
      final m = engine.load('p').manifest;
      expect(m.gameName, '最简包');
      expect(m.points, '积分');
      expect(m.official, 'no');
      expect(m.mapImage, isEmpty);
      expect(m.buttonCoordinates, isEmpty);
    });
  });

  group('stage/*.json', () {
    test('按文件名数字前缀排序，id 优先取 JSON 内 id', () {
      final engine = _engine(
        _source({
          'p': {
            'basicInfo.json': _manifest,
            'stage/2第二关.json': '{"id":"s2","lines":[]}',
            'stage/10第十关.json': '{"id":"s10","lines":[]}',
            'stage/1第一关.json': '{"lines":[{"type":"narration","text":"开场"}]}',
          },
        }),
      );
      final stages = engine.load('p').stages;
      expect(stages.map((s) => s.id), ['1第一关', 's2', 's10']);
      expect(stages.map((s) => s.order), [1, 2, 10]);
      expect(stages.last.sourceFile, '10第十关.json');
    });

    test('空文件跳过且不报错', () {
      final engine = _engine(
        _source({
          'p': {
            'basicInfo.json': _manifest,
            'stage/1有内容.json': '{"id":"s1","lines":[{"text":"a"}]}',
            'stage/2占位.json': '   ',
          },
        }),
      );
      final stages = engine.load('p').stages;
      expect(stages, hasLength(1));
      expect(stages.single.id, 's1');
    });

    test('lineId 缺省按序号兜底，写了就用写的', () {
      final engine = _engine(
        _source({
          'p': {
            'basicInfo.json': _manifest,
            'stage/1.json':
                '{"id":"s1","lines":[{"text":"a"},{"lineId":"custom","text":"b"}]}',
          },
        }),
      );
      final lines = engine.load('p').stages.single.lines;
      expect(lines[0].id, 'l1');
      expect(lines[1].id, 'custom');
    });

    test('sprites 写了就整批替换（含空数组），没写就沿用', () {
      final engine = _engine(
        _source({
          'p': {
            'basicInfo.json': _manifest,
            'stage/1.json': '''
{"id":"s1","lines":[
  {"text":"a","sprites":[{"asset":"x.png","position":"left"}]},
  {"text":"b"},
  {"text":"c","sprites":[]}
]}''',
          },
        }),
      );
      final lines = engine.load('p').stages.single.lines;
      expect(lines[0].declaresSprites, isTrue);
      expect(lines[0].sprites.single.position, 'left');
      expect(lines[1].declaresSprites, isFalse);
      expect(lines[2].declaresSprites, isTrue);
      expect(lines[2].sprites, isEmpty);
    });

    test('分支字段完整解析，next 缺省为终点', () {
      final engine = _engine(
        _source({
          'p': {
            'basicInfo.json': _manifest,
            'stage/1.json': '''
{"id":"s1","lines":[],"checkpoint":[
  {"text":"去下一关","next":"s2","reward":10,"grant":{"key":1}},
  {"text":"结束","reward":0},
  {"text":"门控","condition":"map>=1","check":"check1.json","next":"s2"}
]}''',
          },
        }),
      );
      final cps = engine.load('p').stages.single.checkpoints;
      expect(cps[0].next, 's2');
      expect(cps[0].reward, 10);
      expect(cps[0].grant['key'], 1);
      expect(cps[1].next, isNull);
      expect(cps[2].condition, 'map>=1');
      expect(cps[2].check, 'check1.json');
    });
  });

  group('condition 表达式', () {
    test('省略运算符和数量默认 >= 1', () {
      final c = Condition.parse('map');
      expect(c.isSatisfiedBy({'map': 1}), isTrue);
      expect(c.isSatisfiedBy({}), isFalse);
    });

    test('多项用 && 连接，全部满足才成立', () {
      final c = Condition.parse('label>=2 && gem==1');
      expect(c.isSatisfiedBy({'label': 2, 'gem': 1}), isTrue);
      expect(c.isSatisfiedBy({'label': 1, 'gem': 1}), isFalse);
      expect(c.isSatisfiedBy({'label': 2, 'gem': 0}), isFalse);
    });

    test('六种运算符都支持', () {
      for (final probe in [
        ('a>1', 2, true),
        ('a<2', 1, true),
        ('a<=2', 2, true),
        ('a>=2', 2, true),
        ('a==2', 2, true),
        ('a!=2', 3, true),
        ('a!=2', 2, false),
      ]) {
        final c = Condition.parse(probe.$1);
        expect(
          c.isSatisfiedBy({'a': probe.$2}),
          probe.$3,
          reason: probe.$1,
        );
      }
    });

    test('空表达式视为永远满足', () {
      expect(Condition.parse('').isEmpty, isTrue);
      expect(Condition.parse('   ').isSatisfiedBy({}), isTrue);
    });
  });

  group('check/*.json', () {
    test('id 取文件名去扩展名，type/verify/params 分离', () {
      final engine = _engine(
        _source({
          'p': {
            'basicInfo.json': _manifest,
            'check/check1.json':
                '{"type":"text_answer","verify":"local","answer":"1956"}',
          },
        }),
      );
      final check = engine.load('p').checks['check1']!;
      expect(check.type, 'text_answer');
      expect(check.verify, 'local');
      expect(check.params['answer'], '1956');
      expect(check.params.containsKey('type'), isFalse);
    });

    test('photo_submit 默认要 1 个 image，可被 submit_need 覆盖', () {
      final source = _source({
        'p': {
          'basicInfo.json': _manifest,
          'check/a.json': '{"type":"photo_submit","verify":"server"}',
          'check/b.json':
              '{"type":"photo_submit","submit_need":2,"submit_kinds":["image"]}',
        },
      });
      final checks = _engine(source).load('p').checks;
      expect(checks['a']!.submitRequirement.need, 1);
      expect(checks['a']!.submitRequirement.kinds, {GameItemKind.image});
      expect(checks['b']!.submitRequirement.need, 2);
    });

    test('media_submit 接受图片/音频/视频', () {
      final engine = _engine(
        _source({
          'p': {
            'basicInfo.json': _manifest,
            'check/a.json': '{"type":"media_submit","verify":"local"}',
          },
        }),
      );
      final req = engine.load('p').checks['a']!.submitRequirement;
      expect(req.allows(GameItemKind.audio), isTrue);
      expect(req.allows(GameItemKind.image), isTrue);
      expect(req.allows(GameItemKind.video), isTrue);
      expect(req.needText, isFalse);
    });

    test('text_answer 默认需要文字；ai_points 逐条、ai_pass any 生效', () {
      final engine = _engine(
        _source({
          'p': {
            'basicInfo.json': _manifest,
            'check/a.json':
                '{"type":"text_answer","ai_pass":"any","ai_points":["要点一","  ","要点二"],"fail_text":"再想想"}',
          },
        }),
      );
      final check = engine.load('p').checks['a']!;
      expect(check.submitRequirement.needText, isTrue);
      expect(check.aiEnabled, isTrue);
      expect(check.aiPoints, ['要点一', '要点二']);
      expect(check.aiPassAny, isTrue);
      expect(check.failText, '再想想');
    });

    test('旧写法 ai_criteria 仍识别为 AI 判定', () {
      final engine = _engine(
        _source({
          'p': {
            'basicInfo.json': _manifest,
            'check/a.json':
                '{"type":"text_answer","ai_criteria":"玩家说清了理由"}',
          },
        }),
      );
      final check = engine.load('p').checks['a']!;
      expect(check.aiEnabled, isTrue);
      expect(check.aiPassAny, isFalse);
    });
  });

  group('item/*.json', () {
    test('id 缺省取文件名，kind 缺省按 asset 扩展名推断', () {
      final engine = _engine(
        _source({
          'p': {
            'basicInfo.json': _manifest,
            'item/recording.json':
                '{"name":"录音笔","asset":"assets/audio/x.wav"}',
            'item/gem.json': '{"name":"宝石","initial":3}',
            'item/note.json': '{"name":"笔记","asset":"assets/picture/n.png"}',
          },
        }),
      );
      final items = engine.load('p').items;
      expect(items.keys, containsAll(['recording', 'gem', 'note']));
      expect(items['recording']!.resolvedKind, 'audio');
      expect(items['recording']!.name, '录音笔');
      expect(items['gem']!.initial, 3);
      expect(items['gem']!.isConcrete, isFalse);
      expect(items['note']!.resolvedKind, 'image');
    });
  });

  group('错误处理：不做容错解析', () {
    test('非法 JSON 抛 PackageFormatException', () {
      final engine = _engine(
        _source({
          'p': {
            'basicInfo.json': _manifest,
            'stage/1.json': '{"id":"s1", // 注释\n"lines":[]}',
          },
        }),
      );
      expect(() => engine.load('p'), throwsA(isA<PackageFormatException>()));
    });

    test('缺少 basicInfo.json 的目录不算游戏包', () {
      final engine = _engine(
        _source({
          'p': {'stage/1.json': '{"lines":[]}'},
        }),
      );
      expect(engine.listPackages(), isEmpty);
    });
  });

  group('示例包（随仓库分发）', () {
    test('gamepacks 下示例包全部可解析', () {
      final engine = GameEngine(
        tokenProvider: InMemoryTokenProvider('t'),
      )..configure('gamepacks');
      final names = engine.listPackages();
      expect(names, isNotEmpty);
      for (final name in names) {
        final pkg = engine.load(name);
        expect(pkg.manifest.gameName, isNotEmpty, reason: name);
        expect(pkg.stages, isNotEmpty, reason: name);
      }
    });

    test('larg 示例：6 关 5 校验 2 物品', () {
      final engine = GameEngine(
        tokenProvider: InMemoryTokenProvider('t'),
      )..configure('gamepacks');
      final pkg = engine.load('larg');
      expect(pkg.stages, hasLength(6));
      expect(pkg.checks, hasLength(5));
      expect(pkg.items, hasLength(2));
      expect(pkg.stages.first.id, 's1');
      expect(pkg.stages.last.checkpoints, isEmpty);
    });
  });
}
