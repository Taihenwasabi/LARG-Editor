# LARG Editor 规划（2026-11-23 定稿 · 只规划，未动代码）

> 状态：**规划阶段，一行代码未写**。等用户拍板第 9 节的问题再开工。
> 目标：新建一个**电脑端为主**的 Flutter 软件「LARG Editor」，只有"编辑器 + 运行本地包"，无后端。
> 开源策略：**只开源 LARG Editor**，quq1 其余部分（玩家端、后端、AI 裁判云端、3DS）保持闭源。

---

## 0. 一句话定位

LARG Editor = 桌面工具，做剧本游戏包 + 就地试玩。**不联网、不登录、不上报、不联机**。

---

## 1. 目标 / 非目标

### 目标
1. 作者零代码做出游戏包：基本信息 / 关卡 / 台词 / 分支 / 校验题 / 物品 / 素材。
2. 一键在本地跑刚做的包，所见即所得。
3. 导出标准 `.zip` 游戏包，与 quq1 引擎、3DS 端**共用同一份 JSON 契约**。

### 明确不做
- 后端账号 / 短信 / 登录 / 联机排行榜
- 内购、付费解锁
- 在线素材库、遥测、崩溃上报
- 玩家端（那是 quq1）
- 3DS 移植（那是 `quq_3ds`）
- 多人协作、云存档

---

## 2. 与 quq1 的关系：搬什么、不搬什么

### 搬（复用 quq1 现成资产）
| 来源 | 用途 |
|---|---|
| `lib/engine/**` | 游戏包解析引擎（纯 Dart、零依赖）——核心资产 |
| `lib/page/editor/**` | 编辑器 UI（manifest / stage / item / media / preview / script） |
| `lib/page/gameTalk`、`gameInventory`、`gameNode`、`gameSave` | 预览运行链路 |
| `lib/store/`：localPackStore、packCatalog、draftHistory、itemStore、gameProgress、saveStore、recentGames | 本地包与存档 |
| `lib/service/`：packDirSource、mediaCompressor、filePickService、sharePack、mediaStore | 文件与媒体处理 |
| `lib/i18n/**`（en / zh-CN / ja） | 三语 |
| `lib/component/`：与编辑/播放相关的组件 | 通用件 |

### 不搬（闭源侧的东西）
- `lib/api/`：account、smsAuth、aiChat、aiVerdict、game、appVersion、apiProblem
- `lib/store/`：tokenManager、userController、settingsController（账号/后端相关部分）
- `lib/service/`：updateService、updateDownload_*
- `backend/` 整个目录
- `lib/constants/index.dart` 里的 HttpConstants、AuthConstants
- `android/ios` 原生桥（fusionAuth、image_picker_android 等）
- 玩家侧拍摄/录音能力（`camera`、`record`）→ 编辑器改为"从本地选文件"

### 依赖瘦身
去掉：`dio`、`camera`、`record`、`image_picker_android`、`android_package_installer`、`package_info_plus`、`url_launcher`、`ironpress`、`fvp`、`smart_video_thumbnail`、`audio_decoder`
保留：`file_picker`、`archive`、`share_plus`、`photo_view`、`chewie`、`video_player`、`audioplayers`、`flutter_svg`、`shared_preferences`、`hive_ce`、`path_provider`、`cross_file`

---

## 3. 平台与形态

- 主平台 **Windows**（作者最可能的场景，Flutter desktop 支持成熟），macOS / Linux 次之
- 桌面端已有的 `_io` / `_web` 条件导入分层移植时保留
- 打包：Windows（Inno Setup 或 MSIX）、macOS（.dmg）、Linux（AppImage）
- 窗口细节按桌面习惯做：多窗口、文件拖放、快捷键、最近文件、记住窗口状态

---

## 4. 首版功能范围

### 4.1 包管理
- 新建包（向导：名称 / 简介 / 年龄分级 / 美术风格 / 积分名）
- 打开本地包目录、导入 `.zip`、另存为、导出 `.zip`
- **包自检**（把 `tool/verify_engine.dart` 的逻辑 UI 化，编辑时就报格式错）

### 4.2 编辑
- 基本信息页（沿用 `manifest_tab`）
- 关卡页（沿用 `stage_tab`）：场景条、台词、分支、条件、校验题绑定、奖励与物品
- 校验题页：类型、答案、判定口径、AI 要点（可选）
- 物品页：名称、描述、初始数量、素材
- 素材库（`media_tab`）：图片 / 音频 / 视频，按用户自建文件夹分类，路径写回表单

### 4.3 运行预览
- 编辑器内一键"试玩"：直接进 gameTalk，走完整判定链
- 本地存档（hive_ce）+ 进度回写 + 重置存档

### 4.4 可选：AI 裁判
- 无后端 → 用户自填 OpenAI 兼容 key，**直连**厂商
- key 只存本地，不内置任何厂商密钥，不上报
- 或者直接砍掉（见 9.2）

---

## 5. 不能动的数据契约

包结构保持与 quq1 引擎一致：

```
包名/
  basicInfo.json      Id / gameName / Introduction / official / PublicKey / map / artStyle / points / buttonCoordinates
  stage/*.json        id / lines[] / checkpoint[]
  check/*.json        type / answer / verify / ai_points / submit_kinds ...
  item/*.json         id / name / description / initial / kind
  assets/{picture,audio,video,model}/
```

⚠️ **已知隐患**：`lib/service/webExport.dart` 导出的网页判定与引擎行为不一致（text_answer）。
→ 契约文档 `PACK_FORMAT.md` 里写死"**以引擎为准**"，并把 webExport 的判定改成复用引擎逻辑（本来就是问题3 的欠账）。

---

## 6. 架构建议

### 6.1 仓库形态
**独立新仓库**。monorepo 不推荐 —— quq1 闭源、LARG Editor 开源，混在一起等于间接开源。

### 6.2 代码怎么共用
| 方案 | 优点 | 缺点 |
|---|---|---|
| A. 抽独立 Dart package，quq1 用依赖引 | 一份代码不分叉 | quq1 依赖公开包 = 间接公开引擎 |
| B. 复制一份到 LARG Editor 仓库，自成一体 | 干净、可自由裁剪 | 两边分叉 |
| C. **推荐：LARG Editor 自包含（复制并裁剪）** | quq1 继续开发不被拖累；开源版可自由改 | 需要靠契约文档对齐 |

选 C 的前提（必须做）：写一份 **`PACK_FORMAT.md` 包格式契约**，把 quq1 引擎的字段与判定规则写死，两边都按它改。

### 6.3 Flutter 的硬约束（**本规划最重要的一条**）

Flutter 应用**无法把一部分代码闭源分发** —— 引擎一旦编译进 app，源码就明文躺在用户机器上。

所以实际只有两个选项：
- 整个 LARG Editor 开源（**引擎 + 编辑器一起开源**）
- 整个不开源

"引擎闭源、编辑器开源"在纯 Flutter 桌面 app 里做不到（把引擎做成服务端 → 编辑器就依赖联网；做成 pub.dev 私有包 → 客户端 app 里仍是明文）。

→ **LARG Editor 开源 = 引擎 + 编辑器都开源。** 这一点必须你明确接受。

---

## 7. 开源配套清单

- `LICENSE`（非商用，见待办 P1）+ `README`（中英）+ `NOTICE`（素材来源）+ `PACK_FORMAT.md`（包格式契约）
- `.gitignore` 清理；不提交任何 `.env` / key / 本机路径
- 自带 1~2 个干净示例包（`larg` 已自制干净、`localDemo` 最小）
- 依赖许可证逐个核（fvp / hive_ce / chewie / photo_view / archive / file_picker …）
- `docs/` 放截图与演示 GIF
- 贡献指南（可选）

---

## 8. 里程碑

| 阶段 | 内容 | 产出 |
|---|---|---|
| M0 立项 | 仓库 + 许可 + README 骨架 + **PACK_FORMAT.md 契约** | 可发布的空壳 |
| M1 瘦身移植 | editor + engine 搬过去，去后端，跑通"打开包 → 编辑 → 试玩 → 导出" | 能用的桌面版 |
| M2 包管理 | 导入/导出 zip、素材分类、包自检 UI | 功能完整 |
| M3 打磨 | 控件词典统一、对照视觉稿、三语、桌面交互细节 | 可对外的观感 |
| M4 打包发布 | Windows 安装包 / macOS dmg / Linux AppImage | 可下载 |
| M5 可选 | AI 裁判 + 非商用授权流程 + 反馈渠道 | — |

---

## 9. 待你拍板

- **9.1** 接受"引擎随编辑器一起开源"吗？（见 6.3，Flutter 下无法回避）
- **9.2** LARG Editor 里保留 AI 裁判吗？（玩家/作者自填 key 直连；或砍掉，编辑器只做本地判定）
- **9.3** LICENSE 类型：自定义非商用 / PolyForm Noncommercial / 其他
- **9.4** 3DS 端是否也纳入开源范围？（它也是自有代码，自带 Noto 字库，但启动动画素材必须先换掉）
- **9.5** `official` 字段语义：编辑器要允许作者做非官方包，引擎里"official:no 弹非法游戏包"那条逻辑怎么处理？
- **9.6** 品牌：产品名就用 LARG Editor 吗？LARG 是 Live Action Role Game 的缩写，"游戏包"要不要改叫"剧本工程 / Story Project"之类的中性词

---

## 10. 风险

- 开源 LARG Editor = 公开包格式与玩法设计，别人可照抄（商业友好许可不解决这点）
- 素材：3DS 侧爱音 GIF 必须换；`larg` 已干净；`jubenyouEg2` 本轮已换
- 依赖许可证需逐个审计
- 引擎、编辑器与 quq1 会分叉 —— 靠 `PACK_FORMAT.md` 对齐，不靠代码共享
