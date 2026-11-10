import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import 'flip_digit.dart';

/// Fires a clock-aligned tick at (as close as possible to) every second
/// boundary, re-reading the clock each time rather than accumulating a
/// fixed interval — a direct port of web/app.js's scheduleClockAligned,
/// avoiding drift from Timer coalescing/jitter.
class ClockAlignedTicker {
  Timer? _timer;
  final void Function() onTick;
  ClockAlignedTicker(this.onTick);

  void start() => _schedule();

  void _schedule() {
    final delay = Duration(milliseconds: 1000 - (DateTime.now().millisecondsSinceEpoch % 1000));
    _timer = Timer(delay, () {
      onTick();
      _schedule();
    });
  }

  void stop() => _timer?.cancel();
}

class HeroClock extends StatefulWidget {
  final String tz;
  final String label;
  final Color cardTop;
  final Color cardBottom;
  final Color seamColor;
  final Color ink;
  final Color inkDim;
  final double digitSize;

  /// When set (planner mode), the clock shows this fixed instant instead of
  /// ticking live — the live ClockAlignedTicker keeps running regardless
  /// (recomputing the same fixed value is harmless), so no special pause
  /// logic is needed to enter/leave this mode.
  final DateTime? overrideInstant;

  const HeroClock({
    super.key,
    required this.tz,
    required this.label,
    required this.cardTop,
    required this.cardBottom,
    required this.seamColor,
    required this.ink,
    required this.inkDim,
    required this.digitSize,
    this.overrideInstant,
  });

  @override
  State<HeroClock> createState() => _HeroClockState();
}

class _HeroClockState extends State<HeroClock> {
  late ClockAlignedTicker _ticker;
  String _digits = '000000';

  @override
  void initState() {
    super.initState();
    _digits = _computeDigits();
    _ticker = ClockAlignedTicker(() => setState(() => _digits = _computeDigits()));
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant HeroClock old) {
    super.didUpdateWidget(old);
    if (old.tz != widget.tz || old.overrideInstant != widget.overrideInstant) {
      setState(() => _digits = _computeDigits());
    }
  }

  @override
  void dispose() {
    _ticker.stop();
    super.dispose();
  }

  String _computeDigits() {
    String two(int v) => v.toString().padLeft(2, '0');
    try {
      final loc = tz.getLocation(widget.tz);
      final now = widget.overrideInstant != null ? tz.TZDateTime.from(widget.overrideInstant!, loc) : tz.TZDateTime.now(loc);
      return '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    } catch (_) {
      final now = widget.overrideInstant ?? DateTime.now();
      return '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: widget.digitSize * 0.56,
      fontWeight: FontWeight.w900,
      color: widget.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final digitWidth = widget.digitSize * 0.62;
    final digitHeight = widget.digitSize;

    Widget digit(int i) => FlipDigit(
          value: _digits[i],
          width: digitWidth,
          height: digitHeight,
          textStyle: textStyle,
          cardTop: widget.cardTop,
          cardBottom: widget.cardBottom,
          seamColor: widget.seamColor,
        );

    Widget sep() => Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.digitSize * 0.08),
          child: Text(':', style: TextStyle(fontSize: widget.digitSize * 0.5, color: widget.inkDim, fontWeight: FontWeight.w800)),
        );

    Widget gap() => SizedBox(width: widget.digitSize * 0.03);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(fontSize: 13, letterSpacing: 4, fontWeight: FontWeight.w700, color: widget.inkDim),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            digit(0), gap(), digit(1),
            sep(),
            digit(2), gap(), digit(3),
            sep(),
            digit(4), gap(), digit(5),
          ],
        ),
      ],
    );
  }
}
