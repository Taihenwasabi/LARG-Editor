import 'stage.dart';

class SceneState {
  final String background;
  final List<StageSprite> sprites;
  final String bgm;
  final int backgroundSource;

  const SceneState({
    this.background = '',
    this.sprites = const <StageSprite>[],
    this.bgm = '',
    this.backgroundSource = -1,
  });

  bool get isEmpty => background.isEmpty && sprites.isEmpty && bgm.isEmpty;
}

List<SceneState> sceneTimeline(Stage stage) {
  var background = stage.background?.trim() ?? '';
  var backgroundSource = -1;
  final bgm = stage.bgm?.trim() ?? '';
  var sprites = const <StageSprite>[];
  final out = <SceneState>[];
  for (var i = 0; i < stage.lines.length; i++) {
    final line = stage.lines[i];
    final bg = line.background?.trim() ?? '';
    if (bg.isNotEmpty) {
      background = bg;
      backgroundSource = i;
    }
    if (line.declaresSprites) sprites = line.sprites;
    out.add(
      SceneState(
        background: background,
        sprites: sprites,
        bgm: bgm,
        backgroundSource: backgroundSource,
      ),
    );
  }
  return out;
}

SceneState sceneAt(Stage stage, int index) {
  final timeline = sceneTimeline(stage);
  if (timeline.isEmpty) {
    return SceneState(
      background: stage.background?.trim() ?? '',
      bgm: stage.bgm?.trim() ?? '',
    );
  }
  return timeline[index.clamp(0, timeline.length - 1)];
}

double spriteAlignX(String position) => switch (position) {
  'left' => -0.55,
  'right' => 0.55,
  _ => 0,
};
