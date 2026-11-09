import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A single split-flap digit: a static backdrop (always the new value) plus
/// two animated flaps — the outgoing top half folds away, the incoming
/// bottom half folds into place — mirroring web/app.js's FlipDigit/CSS.
/// Built from Flutter's own 3D Transform rather than a CustomPainter: each
/// half is a clipped, centered Text, which keeps this a straightforward,
/// GPU-composited widget tree instead of hand-rolled canvas glyph layout.
class FlipDigit extends StatefulWidget {
  final String value;
  final double width;
  final double height;
  final TextStyle textStyle;
  final Color cardTop;
  final Color cardBottom;
  final Color seamColor;

  const FlipDigit({
    super.key,
    required this.value,
    required this.width,
    required this.height,
    required this.textStyle,
    required this.cardTop,
    required this.cardBottom,
    required this.seamColor,
  });

  @override
  State<FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<FlipDigit> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late String _oldValue;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  }

  @override
  void didUpdateWidget(covariant FlipDigit old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _oldValue = old.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.width * 0.12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [widget.cardTop, widget.cardBottom],
        ),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: reduceMotion ? _buildCrossfade() : _buildFold(),
    );
  }

  Widget _buildCrossfade() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: _half(widget.value, top: true, key: ValueKey('cf-top-${widget.value}')),
    );
  }

  Widget _buildFold() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final topAngle = t < 0.5 ? (t / 0.5) * (-math.pi / 2) : -math.pi / 2;
        final bottomAngle = t < 0.5 ? math.pi / 2 : (math.pi / 2) * (1 - (t - 0.5) / 0.5);
        final outgoing = t < 1.0 ? _oldValue : widget.value;

        return Stack(
          children: [
            // Static backdrops: always the settled (new) value.
            Positioned.fill(child: Align(alignment: Alignment.topCenter, child: _half(widget.value, top: true))),
            Positioned.fill(child: Align(alignment: Alignment.bottomCenter, child: _half(widget.value, top: false))),
            // Falling top flap: carries the outgoing value.
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateX(topAngle),
                  child: _half(outgoing, top: true),
                ),
              ),
            ),
            // Rising bottom flap: carries the incoming value.
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateX(bottomAngle),
                  child: _half(widget.value, top: false),
                ),
              ),
            ),
            // Center seam, always on top.
            Positioned(
              left: 0,
              right: 0,
              top: widget.height / 2 - 1,
              child: Container(height: 2, color: widget.seamColor),
            ),
          ],
        );
      },
    );
  }

  /// A half-height box showing the top or bottom half of [value], by
  /// rendering the full glyph at full cell height and clipping to one half.
  Widget _half(String value, {required bool top, Key? key}) {
    return ClipRect(
      key: key,
      child: Align(
        alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
        heightFactor: 0.5,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Center(child: Text(value, style: widget.textStyle)),
        ),
      ),
    );
  }
}
