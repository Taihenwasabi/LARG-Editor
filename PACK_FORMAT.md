# 游戏包格式契约 PACK_FORMAT v1

这是 LARG Editor 与所有播放器之间**唯一的契约**。

- **行为基准**：quq1 的 Dart 引擎（`lib/engine/`）是当前已验证的实现；本仓库移植一份，行为必须一致。
- **改格式 = 改契约**：动任何字段，必须同步改这份文档，并同步改所有端的解析器。
- **不做容错解析**：JSON 必须合法。引擎直接用标准 `jsonDecode`，非法 JSON 报错而非猜测。

---

## 1. 目录结构

```
<包名>/
  basicInfo.json          包清单（必需）
  stage/*.json            关卡（至少 1 个）
  check/*.json            校验声明（可选，被 stage 引用时必需）
  item/*.json             剧情物品（可选）
  assets/                 素材（可选）
    picture/  audio/  video/  model/
```

- 目录名即包名。
- `stage/`、`check/`、`item/` 下的文件名**去扩展名后**就是 id（`1面单.json` → id `1面单`；`check1.json` → id `check1`）。
- 关卡排序按**文件名的数字前缀**（`1`、`2`、`3`…）；无数字前缀的排到最后。
- **空文件（0 字节 / 全空白）跳过并告警**，当作占位文件。其余非法 JSON 直接报错。
- 素材路径一律相对**包根**，用 `/` 分隔（如 `assets/picture/x.png`）。

---

## 2. basicInfo.json

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `Id` | string | 建议 | 包唯一 id。注意首字母大写。官方包据此比对合法名单 |
| `gameName` | string | 是 | 包名 |
| `Introduction` | string | 否 | 简介。兼容 `introduction` |
| `official` | string | 否 | `'yes'` / `'no'`，缺省 `'no'`。兼容 `Official` |
| `price` | string | 否 | 价格（字符串，不是数字） |
| `createTime` | string | 否 | 创建日期，如 `2026.9.19` |
| `ageAppropriateness` | string | 否 | 年龄分级，如 `12+` |
| `PublicKey` | string | 否 | 资格校验公钥。兼容 `publicKey` |
| `artStyle` | string | 否 | 美术风格标识，调用端内置对应风格 |
| `points` | string | 否 | 积分名（如「苹果币」），缺省「积分」 |
| `map` | string | 否 | 地图图片相对路径。兼容 `mapImage` |
| `buttonCoordinates` | array | 否 | 可点击按钮坐标，见下 |

`buttonCoordinates` 每项：

```json
{ "id": 1, "x": 320, "y": 640 }
```

坐标是**图片原始像素坐标系**（不是屏幕坐标）。

示例：

```json
{
  "gameName": "异常件 0000",
  "Id": "g-official-larg-0000",
  "official": "yes",
  "Introduction": "夜班分拣员收到一件怪包裹……",
  "price": "0",
  "createTime": "2026.11.7",
  "ageAppropriateness": "12+",
  "PublicKey": "LARG-000…",
  "artStyle": "midnightMailroom",
  "points": "线索点",
  "map": "assets/picture/夜班分拣库.png",
  "buttonCoordinates": [
    { "id": 1, "x": 300, "y": 650 }
  ]
}
```

---

## 3. stage/*.json

```json
{
  "id": "s1",
  "background": "assets/picture/夜班分拣库.png",
  "bgm": "assets/audio/录音笔留言.wav",
  "lines": [ … ],
  "checkpoint": [ … ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | string | 建议 | 关卡 id。缺省用文件名去扩展名 |
| `background` | string | 否 | 关卡默认背景 |
| `bgm` | string | 否 | 关卡 BGM，进入本关循环播放，离开即停 |
| `lines` | array | 否 | 台词行 |
| `checkpoint` | array | 否 | 分支选项。空数组 = 结局 |

### 3.1 行（lines）

```json
{
  "lineId": "arrival",
  "type": "narration",
  "speaker": "客服",
  "text": "只要你在电话里承认自己是机主……",
  "image": "assets/picture/异常件面单.png",
  "audio": "assets/audio/录音笔留言.wav",
  "video": "assets/video/回忆.mp4",
  "background": "assets/picture/别的背景.png",
  "sprites": [ { "asset": "assets/picture/a.png", "position": "left" } ]
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `lineId` | string | 关卡内稳定编号，存档定位「玩到第几段话」用，不随增删漂移。缺省按序号兜底 `l1`、`l2`… |
| `type` | string | `narration`（旁白，缺省）或 `dialogue`（对白） |
| `speaker` | string | 说话人，仅 dialogue 有 |
| `text` | string | 台词正文 |
| `image` | string | 进入本行时显示的图片 |
| `audio` | string | 进入本行时自动播放的音频 |
| `video` | string | 进入本行时播放的视频 |
| `background` | string | 覆盖关卡背景；缺省沿用关卡背景 |
| `sprites` | array | 立绘列表，每项 `{ asset, position }`，`position` ∈ `left` / `center` / `right` |

**继承语义**（重要）：
- `background`：本行没写就沿用关卡背景。
- `sprites`：**写了这个字段就整批替换**（空数组 = 明确不显示立绘）；**没写这个字段就沿用上一行的立绘**。
- `image` / `audio` / `video`：逐行独立，不继承。

### 3.2 分支（checkpoint）

```json
{
  "text": "登记这件异常包裹",
  "next": "s2",
  "condition": "map>=1",
  "check": "check1",
  "reward": 10,
  "grant": { "recording": 1 }
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `text` | string | 选项文案 |
| `next` | string | 跳到哪个关卡 id。**省略或 `null` = 终点** |
| `condition` | string | 显示条件，见 §3.3 |
| `check` | string | 关联的校验 id。写 `check1` 或 `check1.json` 都行（解析时去扩展名匹配） |
| `reward` | number | 通过该节点奖励的积分，缺省 0 |
| `grant` | object | 通过时发放的物品 `{ "物品id": 数量 }`，负数为扣减 |

**id 匹配**：stage 里的 `next` 指向 `stage/*.json` 的 `id`（不是文件名）。

### 3.3 条件表达式（condition）

格式：`项目id 运算符 数量`，多项用 `&&` 连接。

- 运算符：`>=` `<=` `==` `!=` `>` `<`
- 不写运算符和数量 = 默认 `>= 1`
- 例：`map>=1`、`label>=2 && gem==1`

---

## 4. check/*.json

声明式校验。**包里不放任何可执行代码**。

```json
{
  "type": "text_answer",
  "verify": "local",
  "ai_pass": "any",
  "ai_points": ["…判定要点…"],
  "fail_text": "…没通过时给玩家看的提示…"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `type` | string | 校验类型，见下表 |
| `verify` | string | `local`（本地判定）或 `server`（提交后端）。缺省 `local` |
| `answer` | string | 精确答案（`text_answer` + 本地判定用） |
| `requireCount` | number | 需要提交几个物品，缺省按类型推断 |
| `submit_need` | number | 需要提交的物品数量（优先于 `requireCount`） |
| `submit_kinds` | array | 允许的物品类型：`text` / `image` / `audio` / `video` |
| `submit_label` | string | 自定义配额说明文案 |
| `need_text` | bool | 是否需要文字说明 |
| `ai_criteria` | string | 旧写法：AI 判定标准（一整段） |
| `ai_points` | array | AI 判定要点（逐条） |
| `ai_pass` | string | `any` = 任一要点满足即通过；缺省 = 全部满足 |
| `ai_send_items` | array | 判定通过时让 AI 生成并发放的物品，见 §4.2 |
| `fail_text` | string | 没通过时的作者提示 |
| `show_author_hint` | string | `no` = 不显示作者提示（默认显示） |
| `show_ai_reasons` | string | `yes` = 显示 AI 给的理由（默认不显示） |

### 4.1 校验类型

| type | 含义 | 本地判定 | 需要提交 |
|---|---|---|---|
| `photo_submit` | 交照片 | 交够数量即通过 | 1 个 image（可被 `submit_need` 改） |
| `media_submit` | 交媒体（图片/音频/视频任一） | 交够数量即通过 | image / audio / video |
| `text_answer` | 答一段文字 | 与 `answer` 精确比对；走 AI 判定时交给 AI | 需要文字说明 |
| `condition` | 只看条件 | 条件满足即通过 | 无 |

### 4.2 ai_send_items

```json
"ai_send_items": [
  {
    "kind": "text",
    "name": "0000号回执",
    "requirement": "按玩家的决定写一张不超过60字的回执……",
    "quantity": 1,
    "show_in_inventory": "yes",
    "show_in_story": "yes"
  }
]
```

`kind` ∈ `text` / `image` / `audio` / `video`；同名 `kind` 只保留第一条。

---

## 5. item/*.json

剧情物品。

```json
{
  "id": "recording",
  "name": "录音笔",
  "description": "箱子里唯一的线索。",
  "initial": 0,
  "kind": "audio",
  "asset": "assets/audio/录音笔留言.wav"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 物品 id。缺省用文件名去扩展名 |
| `name` | string | 显示名。缺省同 id |
| `description` | string | 描述 |
| `initial` | number | 玩家开局就持有的数量，缺省 0 |
| `kind` | string | `text` / `image` / `audio` / `video`。缺省按 `asset` 扩展名推断 |
| `asset` | string | 物品对应的素材相对路径。空 = 纯概念物品（`isConcrete` = false） |

---

## 6. assets/ 素材

- 目录约定：`assets/picture/`、`assets/audio/`、`assets/video/`、`assets/model/`。目录名只是惯例，引擎按扩展名分派。
- 引擎会做**元数据解析**（不负责渲染/播放）：
  - `glb` → glTF 头 + JSON chunk，得出 meshes / materials / animations 计数
  - `mp4` → ISO-BMFF box 树，得出时长、轨道、编码、分辨率
  - `png` → 宽高
  - `wav` → 采样率 / 声道 / 位深
- `fbx` 等格式只登记路径，不做结构化解析。
- 素材来源必须写进 `NOTICE`。

---

## 7. 判定与状态（运行时约定）

供各端实现对齐，编辑器也要能正确预览：

- **积分**：只有节点被判「通过」才计入 `reward`。
- **物品**：`grant` 在通过时发放；负数扣减。同一节点重复通过**不重复发放**。
- **存档定位**：用 `lineId` 定位「玩到第几段话」；存档与统计必须用它，不用数组下标。
- **已通过节点**：不可被后来的失败覆盖（不降级）。
- **缺失校验**：stage 引用了不存在的 check id = 包错误，不能当成「自动通过」。
- **视频末帧**：视频播完后保留末帧，直到进入没有视频的段落才释放。
- **行音频**：单槽，随台词行切换；进新行先停旧行音频。

---

## 8. 校验清单（编辑器导出前自检）

- [ ] 所有 JSON 合法（无注释、无尾逗号）
- [ ] `stage/*.json` 的 `next` 都能在别的 stage 的 `id` 里找到（或为终点）
- [ ] stage 引用的 `check` id 都存在
- [ ] `condition` 里引用的物品 id 都在 `item/*.json` 里
- [ ] `grant` 里引用的物品 id 都在 `item/*.json` 里
- [ ] 所有素材路径真实存在
- [ ] `basicInfo.json` 的 `Id` / `gameName` 非空
- [ ] 素材来源已登记进 `NOTICE`
