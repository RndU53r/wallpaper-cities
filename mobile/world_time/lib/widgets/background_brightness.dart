import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Wraps a background layer (the generated scene, or a user's own landmark
/// photo) and periodically samples the actual rendered pixels in its
/// bottom strip — where the city ticker sits — reporting whether that
/// strip reads as dark or light. Mirrors web/app.js's Scene
/// _sampleTickerContrast: trusting the real composited pixels (not the
/// Day/Night chrome theme, and not the generative palette's own math)
/// is what keeps the ticker legible over an arbitrary user photo, not just
/// the generated sky.
class BackgroundBrightnessSampler extends StatefulWidget {
  final Widget child;
  final ValueChanged<bool> onSample;
  const BackgroundBrightnessSampler({super.key, required this.child, required this.onSample});

  @override
  State<BackgroundBrightnessSampler> createState() => _BackgroundBrightnessSamplerState();
}

class _BackgroundBrightnessSamplerState extends State<BackgroundBrightnessSampler> {
  final _boundaryKey = GlobalKey();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // A few samples a second is indistinguishable from continuous for a
    // background that only ever changes gradually (slow scene drift, or a
    // static photo) — not worth spending a capture every frame on.
    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) => _sample());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sample());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sample() async {
    try {
      final renderObject = _boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary || renderObject.debugNeedsPaint) return;

      // A tiny capture — just enough pixels to estimate an average; the
      // point is a brightness read, not a usable image.
      final image = await renderObject.toImage(pixelRatio: 0.08);
      final width = image.width;
      final height = image.height;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (byteData == null || width == 0 || height == 0 || !mounted) return;

      final onDark = isBottomStripDark(byteData.buffer.asUint8List(), width, height);
      widget.onSample(onDark);
    } catch (_) {
      // The boundary may not be laid out/painted yet on the very first
      // frame (or mid hot-reload) — just skip this cycle, the next timer
      // tick retries.
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(key: _boundaryKey, child: widget.child);
}

/// Average luminance of the bottom ~18% of a captured RGBA image — roughly
/// where the ticker sits — true if it reads as dark. A top-level function
/// (rather than private to the sampler's State) so the threshold math is
/// unit-testable without needing a real rendering pipeline.
bool isBottomStripDark(Uint8List rgba, int width, int height) {
  if (width <= 0 || height <= 0) return true;
  final stripStart = (height * 0.82).floor().clamp(0, height - 1);
  double sum = 0;
  int count = 0;
  for (var y = stripStart; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      sum += 0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
      count++;
    }
  }
  if (count == 0) return true;
  return (sum / count) < 115;
}
