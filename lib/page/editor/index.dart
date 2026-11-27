
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:larg_editor/component/alert_dialog_basic.dart';
import 'package:larg_editor/component/engine.dart';
import 'package:larg_editor/engine/pack_doctor.dart' as doctor;
import 'package:larg_editor/engine/package_io.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/component/labeled_field.dart';
import 'package:larg_editor/page/editor/card_tree.dart';
import 'package:larg_editor/page/editor/desktop_workbench.dart';
import 'package:larg_editor/page/editor/editor_models.dart';
import 'package:larg_editor/page/editor/editor_media.dart';
import 'package:larg_editor/page/editor/item_tab.dart';
import 'package:larg_editor/page/editor/manifest_tab.dart';
import 'package:larg_editor/page/editor/media_tab.dart';
import 'package:larg_editor/page/editor/preview_page.dart';
import 'package:larg_editor/page/editor/script_import.dart';
import 'package:larg_editor/page/editor/script_text_page.dart';
import 'package:larg_editor/page/editor/stage_tab.dart';
import 'package:larg_editor/page/settings/index.dart';
import 'package:larg_editor/service/pack_dir_source.dart';
import 'package:larg_editor/service/share_pack.dart';
import 'package:larg_editor/service/web_export.dart';
import 'package:larg_editor/store/draft_history.dart';
import 'package:larg_editor/store/game_packages.dart';
import 'package:larg_editor/store/local_pack_store.dart';
import 'package:shared_preferences/shared_preferences.dart';


const String _kDraft = 'editor.draft';
const String _kDraftPrev = 'editor.draft.prev';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late EditablePack _pack;
  bool _loading = true;


  int _packVersion = 0;
  Timer? _saveTimer;

  // 桌面工作台状态（手机模式不使用，但保留以便无缝切换）
  WorkbenchSection _section = WorkbenchSection.stage;
  int? _selectedStage;
  int? _selectedLine;
  int? _selectedCheckpoint;

  // 每关自检问题数（stage 文件名 → 条数）。保存/导入后异步刷新，
  // 判定与「检查」页共用引擎的 PackDoctor，不另写一套。
  final Map<String, int> _issuesByFile = {};

  // 撤销/重做：存整包草稿 JSON 快照。改动去抖后压栈，栈深上限 60。
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  String? _lastSnapshot;
  bool _restoring = false;

  void _commitSnapshot() {
    if (_restoring) return;
    final now = _pack.toDraftJson();
    final prev = _lastSnapshot;
    _lastSnapshot = now;
    if (prev == null || prev == now) return;
    _undoStack.add(prev);
    if (_undoStack.length > 60) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) {
      _snack('没有可以撤销的操作');
      return;
    }
    _restoring = true;
    final current = _pack.toDraftJson();
    final target = _undoStack.removeLast();
    _redoStack.add(current);
    _restoreSnapshot(target);
    _lastSnapshot = target;
    _restoring = false;
  }

  void _redo() {
    if (_redoStack.isEmpty) {
      _snack('没有可以重做的操作');
      return;
    }
    _restoring = true;
    final current = _pack.toDraftJson();
    final target = _redoStack.removeLast();
    _undoStack.add(current);
    _restoreSnapshot(target);
    _lastSnapshot = target;
    _restoring = false;
  }

  void _restoreSnapshot(String json) {
    final stage = _selectedStage;
    final line = _selectedLine;
    final cp = _selectedCheckpoint;
    _swapPack(EditablePack.fromDraftJson(json));
    setState(() {
      _selectedStage = stage != null && stage < _pack.stages.length
          ? stage
          : (_pack.stages.isEmpty ? null : 0);
      final st = _selectedStage == null ? null : _pack.stages[_selectedStage!];
      _selectedLine = st != null && line != null && line < st.lines.length
          ? line
          : null;
      _selectedCheckpoint =
          st != null && cp != null && cp < st.checkpoints.length ? cp : null;
    });
    unawaited(_saveDraft());
  }

  Future<void> _refreshIssues() async {
    final zip = _encodeZip();
    if (zip == null) return;
    final report = _runDoctor(zip);
    final counts = <String, int>{};
    for (final issue in report.issues) {
      final src = issue.source;
      if (src == null) continue;
      final file = src.split('/').last;
      counts[file] = (counts[file] ?? 0) + 1;
    }
    if (!mounted) return;
    setState(() {
      _issuesByFile
        ..clear()
        ..addAll(counts);
    });
  }

  bool _isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);

    _pack = EditablePack.empty();
    _attach(_pack);
    _restoreOnLaunch();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _detach(_pack);
    _tabs.dispose();
    _pack.dispose();
    super.dispose();
  }



  void _attach(EditablePack p) => p.addListener(_scheduleSave);
  void _detach(EditablePack p) => p.removeListener(_scheduleSave);

  void _swapPack(EditablePack next) {
    _detach(_pack);
    _pack = next;
    _attach(_pack);
    _packVersion++;

    // 打开包立刻选中第一关：右侧预览与底部编辑区才有内容，
    // 否则新用户看到的是三个空白面板。
    _selectedStage = next.stages.isEmpty ? null : 0;
    _selectedLine = null;
    _selectedCheckpoint = null;

    unawaited(hydratePackMedia(next));
    if (mounted) setState(() => _loading = false);
  }

  void _scheduleSave() {
    _commitSnapshot();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _saveDraft);
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDraft, _pack.toDraftJson());
    } catch (e) {
      EngineLog.warn('草稿保存失败：$e');
    }
    unawaited(_refreshIssues());
  }

  Future<void> _restoreOnLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = prefs.getString(_kDraft);
      if (!mounted) return;
      if (draft != null) {
        _swapPack(EditablePack.fromDraftJson(draft));
        return;
      }
    } catch (e) {
      EngineLog.warn('读取草稿失败：$e');
    }

    _swapPack(EditablePack.empty());
  }




  Future<void> _import() async {
    final source = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t('editor.import.title')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'folder'),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.folder_open),
              title: Text(t('editor.import.folder')),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'zip'),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.folder_zip_outlined),
              title: Text(t('editor.import.zip')),
            ),
          ),
        ],
      ),
    );
    if (source == null) return;
    if (source == 'folder') {
      await _importFromFolder();
    } else {
      await _importFromZip();
    }
  }


  Future<void> _importFromFolder() async {
    final pick = await pickPackFolder(dialogTitle: t('editor.import.folder'));
    if (!pick.supported) {
      _snack(t('editor.import.folderUnsupported'), error: true);
      return;
    }
    if (pick.canceled) return;
    final files = EditablePack.normalizeRoot(pick.files);
    final issues = EditablePack.validateFileMap(files);
    if (issues.isNotEmpty) {
      await _showInvalid(issues);
      return;
    }
    _swapPack(EditablePack.fromFileMap(files, root: pick.rootName));
    _snack(t('editor.import.done'));
  }


  Future<void> _importFromZip() async {
    FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
    } catch (e) {
      _snack('$e', error: true);
      return;
    }
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      _snack(t('select.loadFailed'), error: true);
      return;
    }
    final files = EditablePack.normalizeRoot(EditablePack.unpackZip(bytes));
    final issues = EditablePack.validateFileMap(files);
    if (issues.isNotEmpty) {
      await _showInvalid(issues);
      return;
    }
    final fileName = f.name;
    final root = fileName.toLowerCase().endsWith('.zip')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    _swapPack(EditablePack.fromFileMap(files, root: root));
    _snack(t('editor.importedZip'));
  }


  Future<void> _showInvalid(List<PackIssue> issues) async {
    if (!mounted) return;
    final lines = issues.map((e) {
      final msg = t('editor.import.invalid.${e.code}');
      return e.detail.isEmpty ? msg : '$msg（${e.detail}）';
    }).join('\n');
    await showAlertDialog(
      context: context,
      title: t('editor.import.invalid.title'),
      content: SingleChildScrollView(child: Text(lines)),
    );
  }




  Uint8List? _encodeZip() {
    try {
      return packToZipBytes(_pack.toArchiveEntries(), rootName: _pack.name);
    } on PackageFormatException catch (e) {
      _snack(e.message, error: true);
      return null;
    }
  }

  /// 检查游戏包：把当前编辑内容走真实的 zip → 引擎 → 自检链路，
  /// 判定逻辑与命令行共用引擎侧的 [PackDoctor]，不复制。
  Future<void> _doctor() async {
    final zipBytes = _encodeZip();
    if (zipBytes == null) return;
    try {
      final files = unpackZipBytes(zipBytes);
      final source = MemoryPackageSource(
        root: 'memory',
        files: {'pack': files},
      );
      final engine = GameEngine(tokenProvider: InMemoryTokenProvider('doctor'))
        ..useSource(source);
      final names = engine.listPackages();
      if (names.isEmpty) {
        _snack(t('editor.import.invalid.noStage'), error: true);
        return;
      }
      final report = doctor.PackDoctor.inspect(engine.load(names.first));
      if (!mounted) return;
      if (!report.hasBlocking) {
        _snack(t('doctor.pass'));
        return;
      }
      final lines = report.issues.map((e) {
        final body = e.source == null
            ? e.message
            : '${e.message}\n${t('doctor.source').replaceAll('{file}', e.source!)}';
        return '• $body';
      }).join('\n\n');
      await showAlertDialog(
        context: context,
        title: t('doctor.fail').replaceAll('{n}', '${report.issues.length}'),
        content: SingleChildScrollView(child: Text(lines)),
      );
    } on PackageFormatException catch (e) {
      if (!mounted) return;
      await showAlertDialog(
        context: context,
        title: t('editor.import.invalid.title'),
        content: Text(e.message),
      );
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _export() async {
    final missing = _missingRequired();
    if (missing.isNotEmpty) {
      final go = await _confirmIncomplete(missing);
      if (go != true) return;
    }
    final zipBytes = _encodeZip();
    if (zipBytes == null) {
      _snack(t('common.error'), error: true);
      return;
    }
    try {
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: t('editor.export'),
        fileName: '${_pack.name.isEmpty ? 'pack' : _pack.name}.zip',
        bytes: zipBytes,
      );
      if (saved == null) {
        _snack(t('common.cancel'));
      } else {
        _snack(t('editor.exportDone'));
      }
    } catch (e) {
      _snack('$e', error: true);
    }
  }


  Future<void> _commitDraft() async {
    final missing = _missingRequired();
    if (missing.isNotEmpty) {
      final go = await _confirmIncomplete(missing);
      if (go != true) return;
    }

    if (_pack.manifest.id.trim().isEmpty) {
      _pack.manifest.id = generateGameId();
    }
    _pack.manifest.official = 'no';

    await _saveDraft();
    final gameName = _pack.manifest.gameName.trim();
    await DraftHistory.upsert(
      DraftEntry(
        id: _pack.manifest.id,
        title: gameName.isNotEmpty ? gameName : _pack.manifest.id,
        subtitle: _pack.manifest.introduction,
        savedAt: DateTime.now().millisecondsSinceEpoch,
        json: _pack.toDraftJson(),
      ),
    );

    final zipBytes = _encodeZip();
    if (zipBytes == null) {
      _snack(t('common.error'), error: true);
      return;
    }
    final ok = await LocalPackStore.saveZip(
      _pack.manifest.id,
      zipBytes,
      displayName: gameName.isNotEmpty ? gameName : t('editor.unnamed'),
      introduction: _pack.manifest.introduction,
    );
    if (!ok) {
      _snack(t('editor.save.quotaError'), error: true);
      return;
    }
    try {
      await GamePackages.registerLocalPackage(_pack.manifest.id, zipBytes);
    } catch (_) {}
    _pack.notify();
    _snack(t('editor.save.done'));
  }


  Future<void> _forward() async {
    final zipBytes = _encodeZip();
    if (zipBytes == null) {
      _snack(t('common.error'), error: true);
      return;
    }
    final fileName = '${_pack.name.isEmpty ? 'pack' : _pack.name}.zip';
    final shared = await shareZip(fileName, zipBytes);
    if (shared) return;
    await _export();
  }


  Future<void> _showRecent() async {
    final list = await DraftHistory.list();
    if (!mounted) return;
    if (list.isEmpty) {
      _snack(t('editor.recent.empty'));
      return;
    }
    final picked = await showDialog<DraftEntry>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t('editor.recent.title')),
        children: [
          for (final e in list)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (e.subtitle.isNotEmpty)
                      Text(e.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      _formatTime(e.savedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(ctx).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    try {
      _swapPack(EditablePack.fromDraftJson(picked.json));
      _snack(t('editor.recent.loaded'));
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  String _formatTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  List<String> _missingRequired() {
    final m = _pack.manifest;
    return <String>[
      if (m.gameName.trim().isEmpty) t('editor.basic.gameName'),
      if (m.introduction.trim().isEmpty) t('editor.basic.intro'),
    ];
  }

  Future<bool?> _confirmIncomplete(List<String> missing) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('editor.incomplete.title')),
        content: SingleChildScrollView(
          child: Text(
            '${t('editor.incomplete.confirm')}\n${missing.join('、')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('common.confirm')),
          ),
        ],
      ),
    );
  }



  Future<void> _newPack() async {

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDraftPrev, _pack.toDraftJson());
    } catch (_) {}
    _swapPack(EditablePack.empty());
    _snack(t('editor.new.cached'));
  }

  Future<void> _restorePrev() async {
    final prefs = await SharedPreferences.getInstance();
    final prev = prefs.getString(_kDraftPrev);
    if (prev == null) {
      _snack(t('editor.draft.none'));
      return;
    }
    try {
      _swapPack(EditablePack.fromDraftJson(prev));
      _snack(t('editor.draft.restored'));
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDraft);
    await prefs.remove(_kDraftPrev);
    _snack(t('editor.draft.cleared'));
  }


  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, size: 20),
        title: Text(label),
      ),
    );
  }

  void _openPreview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorPreviewPage(pack: _pack),
      ),
    );
  }

  void _openScript() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScriptTextPage(pack: _pack),
      ),
    );
  }

  Future<void> _importScript() async {
    await openScriptImport(context, _pack);
  }

  Future<void> _exportWeb() async {
    if (_pack.stages.isEmpty) {
      _snack(t('editor.preview.empty'));
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('editor.webExport.title')),
        content: Text(t('editor.webExport.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('editor.webExport.confirm')),
          ),
        ],
      ),
    );
    if (go != true) return;
    final Uint8List bytes;
    try {
      bytes = Uint8List.fromList(
        utf8.encode(buildStandaloneHtml(_pack)),
      );
    } catch (e) {
      _snack('$e', error: true);
      return;
    }
    try {
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: t('editor.webExport.title'),
        fileName: standaloneFileName(_pack),
        bytes: bytes,
      );
      if (saved == null) {
        _snack(t('common.cancel'));
      } else {
        _snack(t('editor.webExport.done'));
      }
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isDesktop(context) ? _buildDesktop() : _buildMobile();
  }

  // ---------------------------------------------------------------- 桌面工作台
  Widget _buildDesktop() {
    final callbacks = WorkbenchCallbacks(
      onUser: _showUser,
      onSettings: _openSettings,
      onNew: _newPack,
      onOpen: _importFromFolder,
      onSave: _commitDraft,
      onUndo: _undo,
      onRedo: _redo,
      onDoctor: _doctor,
      onScript: _openScript,
      onExport: _export,
      onExportWeb: _exportWeb,
      onImport: _import,
      onRecent: _showRecent,
      onClear: _clearDraft,
      onRestore: _restorePrev,
    );
    return _loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : ListenableBuilder(
            listenable: _pack,
            builder: (context, _) => DesktopWorkbench(
              pack: _pack,
              callbacks: callbacks,
              section: _section,
              onSectionChanged: (s) => setState(() => _section = s),
              selectedStage: _selectedStage,
              selectedLine: _selectedLine,
              selectedCheckpoint: _selectedCheckpoint,
              onSelectStage: (v) => setState(() => _selectedStage = v),
              onSelectLine: (v) => setState(() => _selectedLine = v),
              contentBuilder: _workbenchContent,
              inspectorBuilder: _buildInspector,
              previewBuilder: (stage, line) => EditorPreviewPage(
                pack: _pack,
                embedded: true,
                jumpStage: stage,
                jumpLine: line,
              ),
            ),
          );
  }

  Widget _workbenchContent(WorkbenchSection section) {
    switch (section) {
      case WorkbenchSection.info:
        return _responsive(ManifestTab(key: ValueKey('m$_packVersion'), pack: _pack));
      case WorkbenchSection.stage:
        return CardTree(
          pack: _pack,
          selected: _selectedStage == null
              ? null
              : CardSelection(
                  _selectedStage!,
                  line: _selectedLine,
                  checkpoint: _selectedCheckpoint,
                ),
          onSelect: (sel) => setState(() {
            _selectedStage = sel.stage;
            _selectedLine = sel.line;
            _selectedCheckpoint = sel.checkpoint;
          }),
          issuesByFile: _issuesByFile,
          onAddStage: _addStage,
          onAddLineFor: _addLine,
        );
      case WorkbenchSection.item:
        return _responsive(ItemTab(key: ValueKey('i$_packVersion'), pack: _pack));
      case WorkbenchSection.media:
        return _responsive(MediaTab(key: ValueKey('l$_packVersion'), pack: _pack));
      case WorkbenchSection.doctor:
        return _responsive(_doctorPanel());
      case WorkbenchSection.script:
        return _responsive(ScriptTextPage(pack: _pack));
      case WorkbenchSection.export:
        return _responsive(_exportPanel());
    }
  }

  /// 编辑区（检查器）——卡片上放不下的深度字段，按选中对象切换形态。
  Widget _buildInspector(int? stageIdx, int? lineIdx, int? cpIdx) {
    final stage = stageIdx != null && stageIdx < _pack.stages.length
        ? _pack.stages[stageIdx]
        : null;
    if (stage == null) {
      return Center(
        child: Text(
          t('editor.workbench.inspector.empty'),
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    final line = lineIdx != null && lineIdx < stage.lines.length
        ? stage.lines[lineIdx]
        : null;
    if (line != null) return _lineInspector(stage, line);
    final cp = cpIdx != null && cpIdx < stage.checkpoints.length
        ? stage.checkpoints[cpIdx]
        : null;
    if (cp != null) return _checkpointInspector(stage, cp);
    return _stageInspector(stage);
  }

  Widget _lineInspector(EditableStage stage, EditableLine line) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Text(
          '${stage.id} · ${line.id}',
          style: TextStyle(fontSize: 12, color: scheme.primary),
        ),
        const SizedBox(height: 8),
        // 正文（台词/旁白的核心内容）
        LabeledField(
          label: '正文',
          value: line.text,
          maxLines: 4,
          onChanged: (v) => line.text = v,
        ),
        // 说话人（对白）
        LabeledField(
          label: t('editor.line.speaker'),
          value: line.speaker,
          onChanged: (v) => line.speaker = v,
        ),
        // 行 id
        LabeledField(
          label: t('editor.line.id'),
          value: line.id,
          onChanged: (v) => line.id = v,
        ),
        const SizedBox(height: 8),
        // 类型分段
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'narration', label: Text(t('editor.line.narration'))),
            ButtonSegment(value: 'dialogue', label: Text(t('editor.line.dialogue'))),
          ],
          selected: {line.type == 'dialogue' ? 'dialogue' : 'narration'},
          onSelectionChanged: (s) => setState(() => line.type = s.first),
        ),
        const SizedBox(height: 12),
        Text(t('editor.line.media'), style: TextStyle(fontSize: 12, color: scheme.outline)),
        const SizedBox(height: 4),
        _mediaSlotField(t('editor.line.image'), line.image, (v) => line.image = v),
        _mediaSlotField(t('editor.line.audio'), line.audio, (v) => line.audio = v),
        _mediaSlotField(t('editor.line.video'), line.video, (v) => line.video = v),
        _mediaSlotField(t('editor.line.background'), line.background, (v) => line.background = v),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _removeLine(stage, line),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('删掉这句台词'),
          ),
        ),
      ],
    );
  }

  Widget _mediaSlotField(String label, String value, ValueChanged<String> onChanged) {
    return LabeledField(label: label, value: value, onChanged: onChanged);
  }

  Widget _stageInspector(EditableStage stage) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Text('${stage.id} · ${stage.fileName}',
            style: TextStyle(fontSize: 12, color: scheme.primary)),
        const SizedBox(height: 8),
        LabeledField(
          label: t('editor.line.background'),
          value: stage.background ?? '',
          onChanged: (v) => stage.background = v.isEmpty ? null : v,
        ),
        LabeledField(
          label: t('editor.stage.bgm'),
          value: stage.bgm ?? '',
          onChanged: (v) => stage.bgm = v.isEmpty ? null : v,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _addLine(stage),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('加一句台词'),
            ),
            OutlinedButton.icon(
              onPressed: () => _addCheckpoint(stage),
              icon: const Icon(Icons.call_split, size: 16),
              label: const Text('加一个选项'),
            ),
            OutlinedButton.icon(
              onPressed: () => _removeStage(stage),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('删掉这关'),
            ),
          ],
        ),
      ],
    );
  }

  /// 分支检查器：文案、跳转、条件、校验绑定、奖励。
  Widget _checkpointInspector(EditableStage stage, EditableCheckpoint cp) {
    final scheme = Theme.of(context).colorScheme;
    final stageIds = <String>[
      for (final s in _pack.stages)
        if (s.id.trim().isNotEmpty) s.id,
    ];
    final checkIds = <String>[for (final c in _pack.checks) c.id];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Text('${stage.id} · 选项', style: TextStyle(fontSize: 12, color: scheme.primary)),
        const SizedBox(height: 8),
        LabeledField(
          label: '选项文案',
          value: cp.text,
          onChanged: (v) => cp.text = v,
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: cp.next.trim().isEmpty ? null : cp.next.trim(),
                decoration: const InputDecoration(
                  labelText: '跳转到',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('（结局，不跳转）')),
                  for (final id in stageIds)
                    DropdownMenuItem<String>(value: id, child: Text(id)),
                ],
                onChanged: (v) => setState(() => cp.next = v ?? ''),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: cp.check.trim().isEmpty ? null : cp.check.trim(),
                decoration: const InputDecoration(
                  labelText: '绑定校验',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('（无）')),
                  for (final id in checkIds)
                    DropdownMenuItem<String>(value: id, child: Text(id)),
                ],
                onChanged: (v) => setState(() => cp.check = v ?? ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LabeledField(
          label: '显示条件（形如 map>=1，多个用 && 连接）',
          value: cp.condition,
          onChanged: (v) => cp.condition = v,
        ),
        LabeledField(
          label: '奖励积分',
          value: '${cp.reward}',
          onChanged: (v) => cp.reward = int.tryParse(v.trim()) ?? 0,
        ),
        if (cp.grant.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '通过时发放：${cp.grant.entries.map((e) => '${e.key}×${e.value}').join('、')}',
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _removeCheckpoint(stage, cp),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('删掉这个选项'),
          ),
        ),
      ],
    );
  }

  Widget _doctorPanel() {
    // 复用 _doctor 的判定数据，展示为简单列表（详细交互下一轮接跳转）
    final zipBytes = _encodeZip();
    if (zipBytes == null) return const SizedBox.shrink();
    final report = _runDoctor(zipBytes);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          report.hasBlocking
              ? t('doctor.fail').replaceAll('{n}', '${report.issues.length}')
              : t('doctor.pass'),
          style: TextStyle(color: report.hasBlocking ? Colors.red : Colors.green),
        ),
        const SizedBox(height: 8),
        for (final issue in report.issues)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• ${issue.message}${issue.source == null ? '' : '（${issue.source}）'}'),
          ),
      ],
    );
  }

  doctor.PackReport _runDoctor(Uint8List zipBytes) {
    try {
      final files = unpackZipBytes(zipBytes);
      final source = MemoryPackageSource(root: 'memory', files: {'pack': files});
      final engine = GameEngine(tokenProvider: InMemoryTokenProvider('doctor'))
        ..useSource(source);
      final names = engine.listPackages();
      if (names.isEmpty) {
        return doctor.PackReport([
          const doctor.PackIssue('pack.empty', 'no package', source: null),
        ]);
      }
      return doctor.PackDoctor.inspect(engine.load(names.first));
    } on PackageFormatException catch (e) {
      return doctor.PackReport([doctor.PackIssue('pack.bad', e.message)]);
    }
  }

  Widget _exportPanel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: Text(t('editor.export')),
          onTap: _export,
        ),
        ListTile(
          leading: const Icon(Icons.public),
          title: Text(t('editor.webExport.menu')),
          onTap: _exportWeb,
        ),
      ],
    );
  }

  Future<void> _removeLine(EditableStage stage, EditableLine line) async {
    final idx = stage.lines.indexOf(line);
    if (idx < 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删掉这句台词？'),
        content: Text(line.text.isEmpty ? '（这句还是空的）' : line.text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final stageIdx = _pack.stages.indexOf(stage);
    _pack.removeLine(stage, idx);
    setState(() {
      _selectedStage = stageIdx < 0 ? null : stageIdx;
      _selectedLine = null;
      _selectedCheckpoint = null;
    });
  }

  Future<void> _removeCheckpoint(EditableStage stage, EditableCheckpoint cp) async {
    final idx = stage.checkpoints.indexOf(cp);
    if (idx < 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删掉这个选项？'),
        content: Text(cp.text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final stageIdx = _pack.stages.indexOf(stage);
    _pack.removeCheckpoint(stage, idx);
    setState(() {
      _selectedStage = stageIdx < 0 ? null : stageIdx;
      _selectedLine = null;
      _selectedCheckpoint = null;
    });
  }

  void _addLine(EditableStage stage) {
    final stageIdx = _pack.stages.indexOf(stage);
    if (stageIdx < 0) return;
    _pack.addLine(stage);
    setState(() {
      _selectedStage = stageIdx;
      _selectedLine = stage.lines.length - 1;
      _selectedCheckpoint = null;
    });
  }

  void _addCheckpoint(EditableStage stage) {
    final stageIdx = _pack.stages.indexOf(stage);
    if (stageIdx < 0) return;
    _pack.addCheckpoint(stage);
    setState(() {
      _selectedStage = stageIdx;
      _selectedLine = null;
      _selectedCheckpoint = stage.checkpoints.length - 1;
    });
  }

  Future<void> _removeStage(EditableStage stage) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删掉这一关？'),
        content: Text('「${stage.displayLabel}」以及它下面的台词和选项都会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _pack.removeStage(stage);
    setState(() {
      _selectedStage = _pack.stages.isEmpty ? null : 0;
      _selectedLine = null;
      _selectedCheckpoint = null;
    });
  }

  void _addStage() {
    setState(() {
      _pack.addStage();
      _selectedStage = _pack.stages.isEmpty ? null : _pack.stages.length - 1;
      _selectedLine = null;
      _selectedCheckpoint = null;
    });
  }

  void _showUser() {
    // 无后端：用户 = 作者身份。完整作者面板在用户入口迭代中接入。
    _snack(t('editor.nav.user'));
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  // ---------------------------------------------------------------- 手机模式（原样保留，quq1 复用）
  Widget _buildMobile() {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('editor.title')),
        centerTitle: false,
        actions: [
          // 一等入口：桌面用户第一件事就是打开自己的包，不该藏进三层菜单。
          Tooltip(
            message: t('editor.openFolder.tip'),
            child: TextButton.icon(
              onPressed: _importFromFolder,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(t('editor.openFolder')),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: t('editor.menu'),
            position: PopupMenuPosition.under,
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'recent':
                  _showRecent();
                case 'save':
                  _commitDraft();
                case 'forward':
                  _forward();
                case 'export':
                  _export();
                case 'import':
                  _import();
                case 'new':
                  _newPack();
                case 'preview':
                  _openPreview();
                case 'doctor':
                  _doctor();
                case 'script':
                  _openScript();
                case 'scriptImport':
                  _importScript();
                case 'webExport':
                  _exportWeb();
                case 'restore':
                  _restorePrev();
                case 'clear':
                  _clearDraft();
              }
            },
            itemBuilder: (context) => [
              _menuItem('recent', Icons.history, t('editor.recent.title')),
              _menuItem('save', Icons.save_outlined, t('editor.save')),
              _menuItem('forward', Icons.forward_outlined, t('editor.forward')),
              const PopupMenuDivider(),
              _menuItem('import', Icons.file_open_outlined, t('editor.import')),
              _menuItem('new', Icons.note_add_outlined, t('editor.new')),
              const PopupMenuDivider(),
              _menuItem('preview', Icons.play_circle_outline, t('editor.preview.title')),
              _menuItem('doctor', Icons.health_and_safety_outlined, t('doctor.menu')),
              _menuItem('script', Icons.article_outlined, t('editor.script.title')),
              _menuItem('scriptImport', Icons.text_snippet_outlined, t('editor.scriptImport.menu')),
              const PopupMenuDivider(),
              _menuItem('export', Icons.file_download_outlined, t('editor.export')),
              _menuItem('webExport', Icons.public, t('editor.webExport.menu')),
              const PopupMenuDivider(),
              _menuItem('restore', Icons.undo_outlined, t('editor.draft.restore')),
              _menuItem('clear', Icons.delete_sweep_outlined, t('editor.draft.clear')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: t('editor.tab.basic')),
            Tab(text: t('editor.tab.stage')),
            Tab(text: t('editor.item.title')),
            Tab(text: t('editor.tab.media')),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(

              listenable: _pack,
              builder: (context, _) => TabBarView(
                controller: _tabs,
                children: [
                  _responsive(
                    ManifestTab(key: ValueKey('m$_packVersion'), pack: _pack),
                  ),
                  _responsive(
                    StageTab(key: ValueKey('s$_packVersion'), pack: _pack),
                  ),
                  _responsive(
                    ItemTab(key: ValueKey('i$_packVersion'), pack: _pack),
                  ),
                  _responsive(
                    MediaTab(key: ValueKey('l$_packVersion'), pack: _pack),
                  ),
                ],
              ),
            ),
    );
  }


  Widget _responsive(Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );
  }
}
