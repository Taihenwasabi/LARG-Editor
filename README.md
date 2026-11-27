# LARG Editor

把剧本做成 LARG 游戏包。

一个游戏包 = 一个 JSON 目录。写好它，别的端（手机 App、3DS）就能直接播放。

- **给谁看**：主要写给接到「我写了剧本，帮我做成 LARG 游戏包」这类任务的 AI agent；
  同时也是一个能自己上手改稿的桌面编辑器。
- **格式契约**：**[PACK_FORMAT.md](PACK_FORMAT.md)** —— 唯一权威，先读它。
- **许可**：MIT，见 [LICENSE](LICENSE)。第三方内容与素材来源见 [NOTICE](NOTICE)。
- **安全**：纯本地工具，不联网、不需要登录；唯一的联网是你在设置里自己配的 AI 裁判。
  详见 [SECURITY.md](SECURITY.md)。
- **版本记录**：见 [CHANGELOG.md](CHANGELOG.md)。

---

## 怎么做（agent 工作流）

### 1. 读剧本，拆成关卡

一个关卡 = 若干行台词 + 若干分支选项。
**按剧情转折切关**，不是按字数切。每关通常是「一个场景 → 一个选择」。

### 2. 建目录

```
<包名>/
  basicInfo.json       包清单
  stage/1xxx.json      关卡，按文件名数字前缀排序
  check/1.json         校验题（可选，被关卡引用时才需要）
  item/xxx.json        剧情物品（可选）
  assets/picture/      图片
  assets/audio/        音频
  assets/video/        视频
```

### 3. 写内容

最小可玩的一关：

```json
{
  "id": "s1",
  "lines": [
    { "lineId": "hello", "type": "narration", "text": "夜里十一点五十九分，传送带送来一只没有条码的纸箱。" },
    { "lineId": "ask", "type": "dialogue", "speaker": "同事", "text": "这单你要处理吗？" }
  ],
  "checkpoint": [
    { "text": "登记这件包裹", "next": "s2", "reward": 10 }
  ]
}
```

`basicInfo.json`：

```json
{
  "gameName": "我的剧本",
  "Id": "g-my-pack-0001",
  "official": "no",
  "Introduction": "一句话简介",
  "price": "0",
  "createTime": "2026.11.27",
  "ageAppropriateness": "12+",
  "PublicKey": "MY-PUBKEY-0001",
  "artStyle": "greenPark",
  "points": "积分"
}
```

### 4. 校验（必做）

```
dart run tool/verify_engine.dart <包所在目录>
```

输出 `✅ <包名> 解析成功 | stages=N checks=M assets=K` 才算通过。
报错会指出哪个文件、哪一行、怎么改（JSON 不合法 / 引用了不存在的 check / next 指向不存在的关卡）。

编辑器里也有「检查游戏包」菜单项，判定逻辑与命令行完全相同。

**校验不过就不要交付。** 包里的 JSON 不做容错解析——引擎直接用标准 `jsonDecode`，有一点语法错就整个包读不出来。

**安全**：`dart run tool/verify_engine.dart` 和编辑器的导入/导出共用引擎侧的 zip 解包/打包，会拒绝 `..` 路径穿越、绝对路径、zip bomb（条目 2 万 / 单文件 64MB / 总 256MB 上限）。你无需单独做安全检查。

### 5. 交付

把整个目录给用户。也可以打成 zip（编辑器能导入）。

---

## 几个容易踩的

- **JSON 必须合法**：不能有 `//` 注释、不能有尾逗号。写完先自检。
- **`next` 指向关卡的 `id`**，不是文件名。
- **`sprites` 写了就整批替换**（空数组 = 明确不显示立绘），**不写才沿用上一行**。
- **`check` 引用两种写法都行**：`"check1"` 或 `"check1.json"`。
- **物品 id 要对得上**：`condition` 和 `grant` 里引用的物品必须在 `item/` 里存在，否则那个选项永远不出现。
- **缺失的 check 不等于自动通过** —— 引用错了就是包错了。

---

## 跑编辑器

需要 Flutter 3.41+。

```
flutter pub get
flutter run -d windows
```

打包成可直接分发的程序：

```
flutter build windows --release
# 产物：build/windows/x64/runner/Release/
```

编辑器能做：可视化编辑关卡、本地试玩、AI 裁判判定、导出 zip、导出网页版。

```
flutter test          # 全部测试
flutter analyze       # 静态分析
dart run tool/verify_engine.dart   # 用引擎校验 gamepacks/ 下的示例包
```

## AI 裁判（可选）

关卡里的「校验题」可以指定要点，让 AI 判断玩家提交是否合格：

1. 打开软件 → 左下角齿轮 → 设置
2. 选服务商（DeepSeek / OpenAI / 阿里云百炼 / Moonshot / 本地 Ollama / 自定义）
3. 填模型名和 API 密钥 → 点「测试连接」
4. 试玩到校验题时，点选提交，由 AI 判定并给出未通过的理由

密钥只存在本机，不内置、不上报。不配置时所有题目走本地判定，不会报错。

## 目录

```
lib/engine/          游戏包解析引擎（纯 Dart，零 flutter 依赖）
lib/api/             AI 裁判调用与判定结果解析
lib/service/         媒体落盘、AI 判定编排、导入导出
lib/page/editor/     编辑器工作台（卡片树 / 预览 / 检查器 / 提交面板）
lib/page/settings/   设置页（AI 裁判、语言、关于）
lib/model/           格式相关的纯逻辑
tool/verify_engine.dart  包校验脚本
test/                契约与界面测试
gamepacks/           示例包（localDemo 最小，larg 六幕完整）
PACK_FORMAT.md       包格式契约
NOTICE               第三方内容与素材来源
```

## 贡献

- 改包格式必须同步改 `PACK_FORMAT.md`，并补 `test/` 里的契约测试。
- 新增第三方素材必须登记到 `NOTICE`。
- 提交前跑一遍：`flutter analyze` + `flutter test`。
