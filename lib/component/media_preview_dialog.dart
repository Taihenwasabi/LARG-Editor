library;

import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:larg_editor/component/pack_media.dart';
import 'package:larg_editor/component/video_source.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/service/item_video_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:larg_editor/theme/canvas_skin.dart';
import 'package:larg_editor/theme/tokens.dart';

enum MediaKind { image, audio, video }

const Color _ink = CanvasSkin.lightInk;
const Color _muted = CanvasSkin.lightMuted;
const Color _line = CanvasSkin.lightLine;
const Color _raus = CanvasSkin.accent;

Future<void> openMediaPreview(
  BuildContext context, {
  required MediaKind kind,
  required String assetKey,
  String? title,
  Uint8List? bytes,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'MediaPreview',
    barrierColor: CanvasSkin.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, _) => _DraggableCard(
      kind: kind,
      assetKey: assetKey,
      title: title,
      bytes: bytes,
    ),
  );
}

class _DraggableCard extends StatefulWidget {
  final MediaKind kind;
  final String assetKey;
  final String? title;
  final Uint8List? bytes;

  const _DraggableCard({
    required this.kind,
    required this.assetKey,
    required this.title,
    this.bytes,
  });

  @override
  State<_DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<_DraggableCard> {
  Offset _drag = Offset.zero;

  void _pan(Offset delta) {
    setState(() => _drag += delta);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = (size.width * 0.7).clamp(280.0, 1180.0);
    final h = (size.height * 0.7).clamp(220.0, 940.0);
    final maxX = ((size.width - w) / 2).clamp(0.0, double.infinity);
    final maxY = ((size.height - h) / 2).clamp(0.0, double.infinity);
    final left = (size.width - w) / 2 + _drag.dx.clamp(-maxX, maxX);
    final top = (size.height - h) / 2 + _drag.dy.clamp(-maxY, maxY);

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: w,
          height: h,
          child: Material(
            color: CanvasSkin.white,
            borderRadius: FiftyRadii.xlRadius,
            clipBehavior: Clip.antiAlias,
            elevation: 24,
            shadowColor: CanvasSkin.black54,
            child: Column(
              children: [
                _HandleBar(
                  label: _titleText(),
                  onPan: _pan,
                  onClose: () => Navigator.pop(context),
                ),
                Expanded(
                  child: switch (widget.kind) {
                    MediaKind.image => _PhotoBody(
                      assetKey: widget.assetKey,
                      bytes: widget.bytes,
                    ),
                    MediaKind.audio => _AudioBody(
                      assetKey: widget.assetKey,
                      bytes: widget.bytes,
                    ),
                    MediaKind.video => _VideoBody(
                      assetKey: widget.assetKey,
                      bytes: widget.bytes,
                    ),
                  },
                ),
                _FooterBar(
                  kind: widget.kind,
                  assetKey: widget.assetKey,
                  bytes: widget.bytes,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _titleText() {
    final defaultTitle = switch (widget.kind) {
      MediaKind.image => t('media.image.title'),
      MediaKind.audio => t('media.audio.title'),
      MediaKind.video => t('media.video.title'),
    };
    return widget.title ?? defaultTitle;
  }
}

class _HandleBar extends StatelessWidget {
  final String label;
  final void Function(Offset delta) onPan;
  final VoidCallback onClose;

  const _HandleBar({
    required this.label,
    required this.onPan,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (e) => onPan(e.delta),
      child: Container(
        height: 44,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CanvasSkin.ddd,
                  borderRadius: FiftyRadii.smRadius,
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: Center(
                child: _PillButton(
                  icon: Icons.close_rounded,
                  tooltip: t('common.close'),
                  onTap: onClose,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterBar extends StatelessWidget {
  final MediaKind kind;
  final String assetKey;
  final Uint8List? bytes;

  const _FooterBar({
    required this.kind,
    required this.assetKey,
    this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Icon(
            switch (kind) {
              MediaKind.image => Icons.image_outlined,
              MediaKind.audio => Icons.audiotrack_outlined,
              MediaKind.video => Icons.videocam_outlined,
            },
            size: 16,
            color: _muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fileName(assetKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
          if (kind == MediaKind.image)
            TextButton.icon(
              onPressed: () => _openImageFullScreen(
                context,
                assetKey,
                bytes: bytes,
              ),
              icon: const Icon(Icons.fullscreen, size: 16),
              label: Text(t('media.fullscreen')),
              style: TextButton.styleFrom(
                foregroundColor: _ink,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  static String _fileName(String key) {
    final seg = key.split('/').last;
    return seg.replaceAll('%20', ' ');
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CanvasSkin.f7f7f7,
      shape: const CircleBorder(side: BorderSide(color: _line)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: _ink),
        ),
      ),
    );
  }
}


class _PhotoBody extends StatelessWidget {
  final String assetKey;
  final Uint8List? bytes;

  const _PhotoBody({required this.assetKey, this.bytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CanvasSkin.fafafa,
      child: PhotoView(
        imageProvider: bytes != null
            ? MemoryImage(bytes!)
            : packImageProvider(assetKey),
        backgroundDecoration: const BoxDecoration(color: CanvasSkin.fafafa),
        minScale: PhotoViewComputedScale.contained * 0.6,
        maxScale: PhotoViewComputedScale.covered * 4,
        loadingBuilder: (_, _) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _raus),
        ),
        errorBuilder: (_, _, _) => const _MediaFallback(
          icon: Icons.broken_image_outlined,
          textKey: 'media.image.failed',
        ),
      ),
    );
  }
}

Future<void> _openImageFullScreen(
  BuildContext context,
  String assetKey, {
  Uint8List? bytes,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FullScreenImage(assetKey: assetKey, bytes: bytes),
    ),
  );
}

class _FullScreenImage extends StatelessWidget {
  final String assetKey;
  final Uint8List? bytes;

  const _FullScreenImage({required this.assetKey, this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CanvasSkin.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: PhotoView(
              imageProvider: bytes != null
                  ? MemoryImage(bytes!)
                  : packImageProvider(assetKey),
              backgroundDecoration: const BoxDecoration(color: CanvasSkin.black),
              minScale: PhotoViewComputedScale.contained * 0.6,
              maxScale: PhotoViewComputedScale.covered * 6,
              loadingBuilder: (_, _) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _raus),
              ),
              errorBuilder: (_, _, _) => const _MediaFallback(
                icon: Icons.broken_image_outlined,
                textKey: 'media.image.failed',
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Material(
                  color: CanvasSkin.white24,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close_rounded, color: CanvasSkin.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _VideoBody extends StatefulWidget {
  final String assetKey;
  final Uint8List? bytes;

  const _VideoBody({required this.assetKey, this.bytes});

  @override
  State<_VideoBody> createState() => _VideoBodyState();
}

class _VideoBodyState extends State<_VideoBody> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _failed = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final held = widget.bytes;
      final c = held != null
          ? await createItemVideoController(held, widget.assetKey)
          : await createVideoController(widget.assetKey);
      if (!mounted) {
        c.dispose();
        return;
      }
      final chewie = ChewieController(
        videoPlayerController: c,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _raus,
          handleColor: _raus,
          backgroundColor: CanvasSkin.white24,
          bufferedColor: CanvasSkin.white38,
        ),
      );
      setState(() {
        _video = c;
        _chewie = chewie;
        _initializing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _initializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5, color: _raus),
      );
    }
    final chewie = _chewie;
    if (_failed || chewie == null) {
      return const _MediaFallback(
        icon: Icons.videocam_off_outlined,
        textKey: 'media.video.failed',
      );
    }
    return Container(
      color: CanvasSkin.black,
      child: Chewie(controller: chewie),
    );
  }
}


class _AudioBody extends StatefulWidget {
  final String assetKey;
  final Uint8List? bytes;

  const _AudioBody({required this.assetKey, this.bytes});

  @override
  State<_AudioBody> createState() => _AudioBodyState();
}

class _AudioBodyState extends State<_AudioBody> {
  final AudioPlayer _player = AudioPlayer();
  bool _failed = false;
  bool _ready = false;
  Duration _duration = Duration.zero;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _init();
  }

  Future<void> _init() async {
    try {
      final held = widget.bytes;
      final bytes = held ?? await loadPackMediaBytes(widget.assetKey);
      await _player.setSourceBytes(bytes);
      final d = await _player.getDuration();
      if (!mounted) return;
      setState(() {
        if (d != null) _duration = d;
        _ready = true;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player.state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const _MediaFallback(
        icon: Icons.audiotrack_outlined,
        textKey: 'media.audio.failed',
      );
    }
    return LayoutBuilder(
      builder: (ctx, c) {
        final h = c.maxHeight;
        final iconSize = (h * 0.16).clamp(40.0, 72.0);
        final playSize = (h * 0.14).clamp(38.0, 62.0);
        final gap = (h * 0.03).clamp(8.0, 20.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: h - 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  size: iconSize,
                  color: _ready ? _raus : CanvasSkin.ddd,
                ),
                SizedBox(height: gap),
                if (!_ready)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _raus,
                    ),
                  )
                else ...[
                  _buildProgress(),
                  SizedBox(height: gap),
                  StreamBuilder<PlayerState>(
                    stream: _player.onPlayerStateChanged,
                    builder: (ctx, snap) => Material(
                      color: _ink,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _toggle,
                        child: Icon(
                          snap.data == PlayerState.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: playSize,
                          color: CanvasSkin.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  _buildVolume(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgress() {
    return StreamBuilder<Duration>(
      stream: _player.onPositionChanged,
      builder: (ctx, posSnap) {
        final dur = _duration;
        final pos = posSnap.data ?? Duration.zero;
        final maxMs = dur.inMilliseconds;
        return Column(
          children: [
            Slider(
              value: maxMs <= 0
                  ? 0
                  : pos.inMilliseconds.clamp(0, maxMs).toDouble(),
              max: maxMs <= 0 ? 1 : maxMs.toDouble(),
              activeColor: _raus,
              inactiveColor: CanvasSkin.ddd,
              onChanged: maxMs <= 0
                  ? null
                  : (v) => _player.seek(Duration(milliseconds: v.toInt())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(pos),
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  Text(
                    _fmt(dur),
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVolume() {
    return Row(
      children: [
        const Icon(Icons.volume_down_rounded, color: _muted, size: 20),
        Expanded(
          child: Slider(
            value: _volume.clamp(0.0, 1.0),
            activeColor: _ink,
            inactiveColor: CanvasSkin.ddd,
            onChanged: (v) {
              setState(() => _volume = v);
              _player.setVolume(v);
            },
          ),
        ),
        const Icon(Icons.volume_up_rounded, color: _muted, size: 20),
      ],
    );
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }
}


class _MediaFallback extends StatelessWidget {
  final IconData icon;
  final String textKey;

  const _MediaFallback({required this.icon, required this.textKey});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: CanvasSkin.b0b0b0),
          const SizedBox(height: 10),
          Text(t(textKey), style: const TextStyle(color: _muted, fontSize: 14)),
        ],
      ),
    );
  }
}
