import 'dart:async';
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

/// The 4-6 city strip: a continuously auto-scrolling marquee (the list
/// rendered twice back-to-back for a seamless loop), mirroring the web
/// ticker. Reflows naturally on narrow phones since it's already a
/// horizontal scroll, never truncating a name.
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
  Timer? _clockTimer;
  late ClockAlignedTicker _aligned;
  final double _speed = 24; // px/sec
  Ticker? _driver;
  double _maxScroll = 0;

  @override
  void initState() {
    super.initState();
    _aligned = ClockAlignedTicker(() => setState(() {}));
    _aligned.start();
    _driver = createTicker(_onFrame)..start();
  }

  Duration _lastElapsed = Duration.zero;

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

  @override
  void dispose() {
    _driver?.dispose();
    _aligned.stop();
    _clockTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cities.isEmpty) return const SizedBox.shrink();

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
            itemBuilder: (context, i) {
              final city = tiles[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      city.name.toUpperCase(),
                      style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700, color: widget.inkDim),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hhmm(city.tz),
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: widget.ink),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
