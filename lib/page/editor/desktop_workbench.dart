/// 桌面工作台：左栏导航 + 上半（卡片树 / 预览）+ 底部编辑区。
///
/// 只做布局与选中状态；内容组件（ManifestTab / StageTab / ItemTab / MediaTab）
/// 与业务流程由 EditorPage 通过回调注入——布局层不碰业务，符合分布式设计。
library;

import 'package:flutter/material.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/editor_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 左栏页签。顺序即屏幕顺序；用户/设置固定在两端。
enum WorkbenchSection { info, stage, item, media, doctor, script, export }

/// 工作台对外回调。
class WorkbenchCallbacks {
  final VoidCallback onUser;
  final VoidCallback onSettings;
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onDoctor;
  final VoidCallback onScript;
  final VoidCallback onExport;
  final VoidCallback onExportWeb;
  final VoidCallback onImport;
  final VoidCallback onRecent;
  final VoidCallback onClear;
  final VoidCallback onRestore;

  const WorkbenchCallbacks({
    required this.onUser,
    required this.onSettings,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onUndo,
    required this.onRedo,
    required this.onDoctor,
    required this.onScript,
    required this.onExport,
    required this.onExportWeb,
    required this.onImport,
    required this.onRecent,
    required this.onClear,
    required this.onRestore,
  });
}

class DesktopWorkbench extends StatefulWidget {
  final EditablePack pack;
  final WorkbenchCallbacks callbacks;

  /// 当前内容页签（由外层 EditorPage 持有，保证手机/桌面切换不丢状态）。
  final WorkbenchSection section;
  final ValueChanged<WorkbenchSection> onSectionChanged;

  /// 当前选中的卡片（关卡下标 / 行下标 / 分支下标）。编辑区与预览据此联动。
  final int? selectedStage;
  final int? selectedLine;
  final int? selectedCheckpoint;
  final ValueChanged<int?> onSelectStage;
  final ValueChanged<int?> onSelectLine;

  /// 各内容页签的构建器（EditorPage 注入，避免工作台依赖具体页签实现）。
  final Widget Function(WorkbenchSection section) contentBuilder;

  /// 编辑区构建器（选中卡片的深度字段）。
  final Widget Function(
    int? stage,
    int? line,
    int? checkpoint,
  ) inspectorBuilder;

  /// 预览构建器（嵌入模式，含跳转联动）。
  final Widget Function(int? stage, int? line) previewBuilder;

  const DesktopWorkbench({
    super.key,
    required this.pack,
    required this.callbacks,
    required this.section,
    required this.onSectionChanged,
    required this.selectedStage,
    required this.selectedLine,
    required this.selectedCheckpoint,
    required this.onSelectStage,
    required this.onSelectLine,
    required this.contentBuilder,
    required this.inspectorBuilder,
    required this.previewBuilder,
  });

  @override
  State<DesktopWorkbench> createState() => _DesktopWorkbenchState();
}

class _DesktopWorkbenchState extends State<DesktopWorkbench> {
  // 显隐（持久化键见 _Prefs）
  bool _showTree = true;
  bool _showPreview = true;
  bool _showInspector = true;
  bool _toolbarVisible = true;

  // 尺寸比例：树占上半区宽度、编辑区占整体高度
  double _treeFraction = 0.33;
  double _inspectorFraction = 0.26;

  static const double _navWidth = 64;
  static const double _toolbarHeight = 48;
  static const double _inspectorMin = 120;
  static const double _treeMin = 320;
  static const double _previewMin = 280;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    // 轻量读取，失败静默（偏好是可有可无的锦上添花）
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _treeFraction = prefs.getDouble(_Prefs.treeFraction) ?? _treeFraction;
        _inspectorFraction =
            prefs.getDouble(_Prefs.inspectorFraction) ?? _inspectorFraction;
        _showTree = prefs.getBool(_Prefs.showTree) ?? _showTree;
        _showPreview = prefs.getBool(_Prefs.showPreview) ?? _showPreview;
        _showInspector = prefs.getBool(_Prefs.showInspector) ?? _showInspector;
      });
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_Prefs.treeFraction, _treeFraction);
      await prefs.setDouble(_Prefs.inspectorFraction, _inspectorFraction);
      await prefs.setBool(_Prefs.showTree, _showTree);
      await prefs.setBool(_Prefs.showPreview, _showPreview);
      await prefs.setBool(_Prefs.showInspector, _showInspector);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _navRail(),
            Expanded(
              child: Column(
                children: [
                  if (_toolbarVisible) _toolbar(),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(flex: 100 - (_inspectorFraction * 100).round(), child: _upper()),
                        if (_showInspector) _inspectorHandle(),
                        if (_showInspector)
                          SizedBox(
                            height: () {
                              final h = MediaQuery.sizeOf(context).height;
                              return (_inspectorFraction * h).clamp(
                                _inspectorMin.toDouble(),
                                h * 0.7,
                              );
                            }(),
                            child: _inspector(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 左栏 ----------
  Widget _navRail() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: _navWidth,
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _navButton(
            icon: Icons.person_outline,
            label: t('editor.nav.user'),
            selected: false,
            onTap: widget.callbacks.onUser,
          ),
          const SizedBox(height: 4),
          ..._sectionButtons(),
          const Spacer(),
          _navButton(
            icon: Icons.settings_outlined,
            label: t('editor.nav.settings'),
            selected: false,
            onTap: widget.callbacks.onSettings,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> _sectionButtons() {
    // 内容与工具同列（用户拍板：条目少，不分组）。
    const items = <(WorkbenchSection, IconData, String)>[
      (WorkbenchSection.info, Icons.info_outline, 'editor.nav.info'),
      (WorkbenchSection.stage, Icons.account_tree_outlined, 'editor.nav.stage'),
      (WorkbenchSection.item, Icons.backpack_outlined, 'editor.nav.item'),
      (WorkbenchSection.media, Icons.perm_media_outlined, 'editor.nav.media'),
      (WorkbenchSection.doctor, Icons.health_and_safety_outlined, 'editor.nav.doctor'),
      (WorkbenchSection.script, Icons.article_outlined, 'editor.nav.script'),
      (WorkbenchSection.export, Icons.file_download_outlined, 'editor.nav.export'),
    ];
    return [
      for (final e in items)
        _navButton(
          icon: e.$2,
          label: t(e.$3),
          selected: widget.section == e.$1,
          onTap: () => widget.onSectionChanged(e.$1),
        ),
    ];
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: _navWidth,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 顶部工具栏 ----------
  Widget _toolbar() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _toolbarHeight,
      child: Row(
        children: [
          _toolButton(Icons.note_add_outlined, t('editor.new'), widget.callbacks.onNew),
          _toolButton(Icons.folder_open_outlined, t('editor.open'), widget.callbacks.onOpen),
          _toolButton(Icons.save_outlined, t('editor.save'), widget.callbacks.onSave),
          const SizedBox(width: 8),
          _toolButton(Icons.undo_outlined, t('common.undo'), widget.callbacks.onUndo),
          _toolButton(Icons.redo_outlined, t('common.redo'), widget.callbacks.onRedo),
          const Spacer(),
          Text(
            widget.pack.manifest.gameName.isEmpty
                ? t('editor.unnamed')
                : widget.pack.manifest.gameName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const Spacer(),
          _toolButton(
            Icons.account_tree_outlined,
            t('editor.workbench.showTree'),
            () => setState(() {
              _showTree = !_showTree;
              _savePrefs();
            }),
            active: _showTree,
          ),
          _toolButton(
            Icons.play_circle_outline,
            t('editor.workbench.showPreview'),
            () => setState(() {
              _showPreview = !_showPreview;
              _savePrefs();
            }),
            active: _showPreview,
          ),
          _toolButton(
            Icons.tune_outlined,
            t('editor.workbench.showInspector'),
            () => setState(() {
              _showInspector = !_showInspector;
              _savePrefs();
            }),
            active: _showInspector,
          ),
          _toolButton(
            Icons.fullscreen_outlined,
            t('editor.workbench.focus'),
            _focusMode,
          ),
          _toolButton(Icons.expand_less, t('common.collapse'), () {
            setState(() => _toolbarVisible = false);
          }),
        ],
      ),
    );
  }

  Widget _toolButton(
    IconData icon,
    String tip,
    VoidCallback onTap, {
    bool active = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Icon(
            icon,
            size: 19,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _focusMode() {
    setState(() {
      _showTree = false;
      _showInspector = false;
      _showPreview = true;
    });
    _savePrefs();
  }

  // ---------- 上半区：树 | 预览 ----------
  Widget _upper() {
    if (!_showTree && !_showPreview) {
      return Center(child: Text(t('editor.workbench.showTree')));
    }
    if (!_showTree) return _previewPane();
    if (!_showPreview) return _treePane();
    return Row(
      children: [
        SizedBox(
          width: () {
            final w = MediaQuery.sizeOf(context).width - _navWidth;
            return (_treeFraction * w).clamp(
              _treeMin.toDouble(),
              w - _previewMin,
            );
          }(),
          child: _treePane(),
        ),
        _verticalHandle(),
        Expanded(child: _previewPane()),
      ],
    );
  }

  /// 树面板：统一深色底，禁止任何内容组件自带浅色底造成突兀色块。
  Widget _treePane() {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: widget.contentBuilder(widget.section),
    );
  }

  Widget _previewPane() => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: widget.previewBuilder(
          widget.selectedStage,
          widget.selectedLine,
        ),
      );

  // ---------- 隐形拖拽手柄 ----------
  Widget _verticalHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) {
          final w = MediaQuery.sizeOf(context).width - _navWidth;
          setState(() {
            _treeFraction = (_treeFraction + d.delta.dx / w).clamp(0.2, 0.6);
          });
        },
        onHorizontalDragEnd: (_) => _savePrefs(),
        onDoubleTap: () {
          setState(() => _treeFraction = 0.33);
          _savePrefs();
        },
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              height: 40,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inspectorHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (d) {
          final h = MediaQuery.sizeOf(context).height;
          setState(() {
            _inspectorFraction = (_inspectorFraction - d.delta.dy / h)
                .clamp(0.12, 0.7);
          });
        },
        onVerticalDragEnd: (_) => _savePrefs(),
        onDoubleTap: () {
          setState(() => _inspectorFraction = 0.26);
          _savePrefs();
        },
        child: Container(
          height: 8,
          color: Colors.transparent,
        ),
      ),
    );
  }

  // ---------- 编辑区 ----------
  Widget _inspector() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Text(
              _breadcrumb(),
              style: TextStyle(
                fontSize: 11,
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: widget.inspectorBuilder(
              widget.selectedStage,
              widget.selectedLine,
              widget.selectedCheckpoint,
            ),
          ),
        ],
      ),
    );
  }

  String _breadcrumb() {
    final si = widget.selectedStage;
    if (si == null || si >= widget.pack.stages.length) {
      return '${t('editor.workbench.inspector')} · ${t('editor.workbench.inspector.empty')}';
    }
    final stage = widget.pack.stages[si];
    final li = widget.selectedLine;
    if (li != null && li < stage.lines.length) {
      final line = stage.lines[li];
      final prefix = line.type == 'dialogue' ? line.speaker : t('editor.line.narration');
      return '${stage.id} · ${prefix.isNotEmpty ? prefix : line.id}';
    }
    return '${stage.id} · ${stage.fileName}';
  }
}

class _Prefs {
  static const String treeFraction = 'workbench.treeFraction';
  static const String inspectorFraction = 'workbench.inspectorFraction';
  static const String showTree = 'workbench.showTree';
  static const String showPreview = 'workbench.showPreview';
  static const String showInspector = 'workbench.showInspector';
}
