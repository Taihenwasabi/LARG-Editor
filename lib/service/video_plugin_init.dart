/// 视频/音频平台实现注册——桌面端接缝。
///
/// 官方 video_player 在 Windows/Linux 没有平台实现，`VideoPlayerPlatform`
/// 会退回抛 UnimplementedError 的基类，音视频必然播放失败。这里用 fvp
/// （libffmpeg 预编译，随 pub 包分发，构建期零外部下载）补位。
///
/// 与 quq1 的接缝同名同形，玩家端后续可直接对齐。
library;

import 'package:fvp/fvp.dart' as fvp;

bool _registered = false;

/// 在 `runApp` 之前调用一次。
void initVideoPlugin() {
  if (_registered) return;
  _registered = true;
  fvp.registerWith(options: {
    'platforms': ['windows', 'macos', 'linux'],
  });
}
