import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/cities_db.dart';
import '../state/app_state.dart';
import 'hero_clock.dart';

String _hhmm(String timezone, [DateTime? at]) {
  try {
    final loc = tz.getLocation(timezone);
    final now = at != null ? tz.TZDateTime.from(at, loc) : tz.TZDateTime.now(loc);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}';
  } catch (_) {
    return '--:--';
  }
}

const double _tileHorizontalPadding = 18;
const _nameStyle = TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700);
const _timeStyle = TextStyle(fontSize: 26, fontWeight: FontWeight.w800);
const _badgeStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w800);

double _textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// The 4-6 city strip. If every city's tile fits in the available width in
/// one pass, it's shown once, centered, standing still — matching the web
/// ticker's behavior. Only when a single pass would overflow does this
/// duplicate the list and auto-scroll as a seamless marquee.
class CityTicker extends StatefulWidget {
  final List<CityEntry> cities;
  final Color ink;
  final Color inkDim;
  final Color accent;

  /// A soft halo behind the tile text — set from the sampled background
  /// brightness (see BackgroundBrightnessSampler), same purpose as the ink
  /// color swap: keeps the tile legible over a textured photo, not just a
  /// flat generated sky.
  final List<Shadow>? textShadows;

  /// Planner mode: a fixed instant to show instead of the live clock, which
  /// city is the drag anchor (highlighted, and excluded from day-delta
  /// badges since it's the reference everything else is compared against),
  /// and a tap handler so tapping another tile re-anchors the drag to it.
  final DateTime? overrideInstant;
  final String? anchorTz;
  final void Function(String tz)? onCityTap;

  const CityTicker({
    super.key,
    required this.cities,
    required this.ink,
    required this.inkDim,
    this.accent = Colors.orange,
    this.textShadows,
    this.overrideInstant,
    this.anchorTz,
    this.onCityTap,
  });

  @override
  State<CityTicker> createState() => _CityTickerState();
}

class _CityTickerState extends State<CityTicker> with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final ClockAlignedTicker _aligned;
  static const double _speed = 24; // px/sec
  Ticker? _driver;
  double _maxScroll = 0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _aligned = ClockAlignedTicker(() => setState(() {}));
    _aligned.start();
  }

  @override
  void dispose() {
    _driver?.dispose();
    _aligned.stop();
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureDriver(bool needed) {
    if (needed && _driver == null) {
      _driver = createTicker(_onFrame)..start();
    } else if (!needed && _driver != null) {
      _driver!.dispose();
      _driver = null;
      _maxScroll = 0;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  void _onFrame(Duration elapsed) {
    if (!_scrollController.hasClients) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (_maxScroll <= 0) return;

    var next = _scrollController.offset + _speed * dt;
    if (next >= _maxScroll) next -= _maxScroll;
    _scrollController.jumpTo(next);
  }

  Widget _tile(CityEntry city) {
    final isAnchor = widget.anchorTz != null && city.tz == widget.anchorTz;
    final delta = widget.overrideInstant != null && widget.anchorTz != null
        ? dayDeltaLabel(city.tz, widget.anchorTz!, widget.overrideInstant!)
        : null;
    final tileColor = isAnchor ? widget.accent : widget.ink;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _tileHorizontalPadding),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onCityTap != null ? () => widget.onCityTap!(city.tz) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              city.name.toUpperCase(),
              style: _nameStyle.copyWith(color: isAnchor ? widget.accent : widget.inkDim, shadows: widget.textShadows),
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hhmm(city.tz, widget.overrideInstant),
                  style: _timeStyle.copyWith(color: tileColor, shadows: widget.textShadows),
                ),
                if (delta != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, top: 2),
                    child: Text(delta, style: _badgeStyle.copyWith(color: widget.accent)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cities.isEmpty) {
      _ensureDriver(false);
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double singlePassWidth = 0;
        for (final city in widget.cities) {
          final nameWidth = _textWidth(city.name.toUpperCase(), _nameStyle);
          final timeWidth = _textWidth(_hhmm(city.tz, widget.overrideInstant), _timeStyle);
          singlePassWidth += (nameWidth > timeWidth ? nameWidth : timeWidth) + _tileHorizontalPadding * 2;
        }
        final fits = singlePassWidth <= constraints.maxWidth;
        _ensureDriver(!fits);

        if (fits) {
          return SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.cities.map(_tile).toList(growable: false),
            ),
          );
        }

        final tiles = [...widget.cities, ...widget.cities];
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
            stops: [0, 0.06, 0.94, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: SizedBox(
            height: 70,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (n) {
                _maxScroll = n.metrics.maxScrollExtent / 2; // one pass's width
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tiles.length,
                itemBuilder: (context, i) => _tile(tiles[i]),
              ),
            ),
          ),
        );
      },
    );
  }
}
