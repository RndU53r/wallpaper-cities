import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/cities_db.dart';
import 'hero_clock.dart';

String _hhmm(String timezone) {
  try {
    final loc = tz.getLocation(timezone);
    final now = tz.TZDateTime.now(loc);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}';
  } catch (_) {
    return '--:--';
  }
}

const double _tileHorizontalPadding = 18;
const _nameStyle = TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700);
const _timeStyle = TextStyle(fontSize: 26, fontWeight: FontWeight.w800);

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

  const CityTicker({super.key, required this.cities, required this.ink, required this.inkDim});

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _tileHorizontalPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            city.name.toUpperCase(),
            style: _nameStyle.copyWith(color: widget.inkDim),
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
          const SizedBox(height: 4),
          Text(_hhmm(city.tz), style: _timeStyle.copyWith(color: widget.ink)),
        ],
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
          final timeWidth = _textWidth(_hhmm(city.tz), _timeStyle);
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
