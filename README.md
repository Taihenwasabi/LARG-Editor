<<<<<<< HEAD
# LARG Editor

把剧本做成 LARG 游戏包。

一个游戏包 = 一个 JSON 目录。写好它，别的端（手机 App、3DS）就能直接播放。

- **给谁看**：接到「我写了剧本，帮我做成 LARG 游戏包」这类任务的 AI agent。
- **格式契约**：**[PACK_FORMAT.md](PACK_FORMAT.md)** —— 唯一权威，先读它。
- **许可**：MIT，见 [LICENSE](LICENSE)。素材来源见 [NOTICE](NOTICE)。

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

## 跑编辑器（可选，需要 Flutter 3.41+）

```
flutter pub get
flutter run -d windows
```

编辑器能做：可视化编辑关卡、本地试玩、导出 zip、导出网页版。

```
flutter test          # 包格式契约测试
flutter analyze       # 静态分析
```

## 目录

```
lib/engine/          游戏包解析引擎（纯 Dart，零 flutter 依赖）
lib/model/           格式相关的纯逻辑
tool/verify_engine.dart  包校验脚本
test/                契约测试
gamepacks/           示例包（localDemo 最小，larg 六幕完整）
PACK_FORMAT.md       包格式契约
```
=======
# LARG-Editor
An New Engine for Novel Game.
>>>>>>> 4f8971e3e4c12a310e90257ff7d432ca57561408
