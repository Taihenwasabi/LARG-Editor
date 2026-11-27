/// 平台相关「选择游戏包文件夹」能力（可迁移接口）。
///
/// 编辑器「导入」需要一次选中**整个包目录**（含 basicInfo.json / stage/ / check/）。
/// 该接缝按平台条件导出实现，业务层只依赖本文件的签名，不直接触碰 `dart:io`。
///
/// LARG Editor 是桌面工具，只走原生实现（真实目录遍历）。
library;

export 'pack_dir_source_io.dart';
