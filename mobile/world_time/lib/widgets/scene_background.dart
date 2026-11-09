import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

/// Day/night sky palette, keyframed by hour-of-day and linearly
/// interpolated — a direct port of web/app.js's SKY_KEYFRAMES/skyPalette.
class _SkyKeyframe {
  final double hour;
  final Color top;
  final Color bottom;
  final Color silhouette;
  final double stars;
  const _SkyKeyframe(this.hour, this.top, this.bottom, this.silhouette, this.stars);
}

const _skyKeyframes = [
  _SkyKeyframe(0, Color(0xFF0B1026), Color(0xFF1B2550), Color(0xFF05060D), 1),
  _SkyKeyframe(6, Color(0xFF2B2F63), Color(0xFFFF8A65), Color(0xFF11131F), 0.15),
  _SkyKeyframe(12, Color(0xFF4FA8E8), Color(0xFFBFE3F7), Color(0xFF10151C), 0),
  _SkyKeyframe(18, Color(0xFF2A1F4D), Color(0xFFFF6B4A), Color(0xFF0C0D16), 0.1),
  _SkyKeyframe(24, Color(0xFF0B1026), Color(0xFF1B2550), Color(0xFF05060D), 1),
];

class SkyPalette {
  final Color top;
  final Color bottom;
  final Color silhouette;
  final double stars;
  final double daylight;
  const SkyPalette(this.top, this.bottom, this.silhouette, this.stars, this.daylight);
}

SkyPalette skyPalette(double hourFraction) {
  var lo = _skyKeyframes.first;
  var hi = _skyKeyframes.last;
  for (var i = 0; i < _skyKeyframes.length - 1; i++) {
    if (hourFraction >= _skyKeyframes[i].hour && hourFraction <= _skyKeyframes[i + 1].hour) {
      lo = _skyKeyframes[i];
      hi = _skyKeyframes[i + 1];
      break;
    }
  }
  final span = (hi.hour - lo.hour) == 0 ? 1 : (hi.hour - lo.hour);
  final t = ((hourFraction - lo.hour) / span).clamp(0.0, 1.0);
  return SkyPalette(
    Color.lerp(lo.top, hi.top, t)!,
    Color.lerp(lo.bottom, hi.bottom, t)!,
    Color.lerp(lo.silhouette, hi.silhouette, t)!,
    lo.stars + (hi.stars - lo.stars) * t,
    1 - (lo.stars + (hi.stars - lo.stars) * t),
  );
}

double localHourFraction(String timezone) {
  try {
    final loc = tz.getLocation(timezone);
    final now = tz.TZDateTime.now(loc);
    return now.hour + now.minute / 60 + now.second / 3600;
  } catch (_) {
    final now = DateTime.now();
    return now.hour + now.minute / 60 + now.second / 3600;
  }
}

class _Building {
  final double xFrac, widthFrac, heightFrac;
  final bool lit;
  final int litRows;
  const _Building(this.xFrac, this.widthFrac, this.heightFrac, this.lit, this.litRows);
}

class _Blob {
  final double xFrac, yFrac, rFrac, speed, phase, dir;
  const _Blob(this.xFrac, this.yFrac, this.rFrac, this.speed, this.phase, this.dir);
}

class _Star {
  final double x, y, r, tw;
  const _Star(this.x, this.y, this.r, this.tw);
}

class CityScene {
  final List<_Building> buildings;
  final List<_Blob> blobs;
  final List<_Star> stars;
  final double hueShiftDeg;
  const CityScene(this.buildings, this.blobs, this.stars, this.hueShiftDeg);
}

int _hashString(String s) {
  var h = 0x811c9dc5;
  for (final codeUnit in s.codeUnits) {
    h ^= codeUnit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// Deterministic PRNG (mulberry32) seeded from the timezone string, so each
/// city always renders the same scene without needing to store anything.
class _Rng {
  int _a;
  _Rng(int seed) : _a = seed;
  double next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _a;
    t = (_mul32(t ^ (t >>> 15), t | 1)) & 0xFFFFFFFF;
    t = (t ^ (t + _mul32(t ^ (t >>> 7), t | 61))) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296.0;
  }

  static int _mul32(int a, int b) => (a * b) & 0xFFFFFFFF;
}

final Map<String, CityScene> _sceneCache = {};

CityScene sceneFor(String tz) {
  return _sceneCache.putIfAbsent(tz, () {
    final rng = _Rng(_hashString(tz));
    final buildingCount = 12 + (rng.next() * 6).floor();
    final buildings = <_Building>[];
    var x = 0.0;
    for (var i = 0; i < buildingCount; i++) {
      final widthFrac = 0.04 + rng.next() * 0.05;
      final heightFrac = 0.1 + rng.next() * 0.38;
      buildings.add(_Building(x, widthFrac, heightFrac, rng.next() > 0.45, 2 + (rng.next() * 4).floor()));
      x += widthFrac * (0.55 + rng.next() * 0.4);
      if (x > 1) break;
    }
    final blobs = List.generate(
      3,
      (_) => _Blob(rng.next(), 0.1 + rng.next() * 0.35, 0.18 + rng.next() * 0.22, 0.2 + rng.next() * 0.3,
          rng.next() * math.pi * 2, rng.next() > 0.5 ? 1.0 : -1.0),
    );
    final stars = List.generate(
      70,
      (_) => _Star(rng.next(), rng.next() * 0.65, 0.5 + rng.next() * 1.1, rng.next() * math.pi * 2),
    );
    final hueShift = (rng.next() - 0.5) * 24;
    return CityScene(buildings, blobs, stars, hueShift);
  });
}

/// Generative, per-city, day/night-aware background with a gentle Ken Burns
/// drift — a CustomPainter port of web/app.js's Scene._drawCity.
class SceneBackgroundPainter extends CustomPainter {
  final String tz;
  final double animationSeconds;

  SceneBackgroundPainter({required this.tz, required this.animationSeconds});

  @override
  void paint(Canvas canvas, Size size) {
    final scene = sceneFor(tz);
    final palette = skyPalette(localHourFraction(tz));
    final w = size.width, h = size.height;
    final t = animationSeconds;

    canvas.save();
    final zoom = 1.04 + math.sin(t * 0.03) * 0.025;
    final panX = math.sin(t * 0.015) * w * 0.015;
    final panY = math.cos(t * 0.012) * h * 0.01;
    canvas.translate(w / 2 + panX, h / 2 + panY);
    canvas.scale(zoom);
    canvas.translate(-w / 2, -h / 2);

    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.top, palette.bottom],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    if (palette.stars > 0.02) {
      for (final s in scene.stars) {
        final tw = 0.55 + 0.45 * math.sin(t * 1.3 + s.tw);
        canvas.drawCircle(
          Offset(s.x * w, s.y * h),
          s.r,
          Paint()..color = Colors.white.withOpacity(0.5 * tw * palette.stars),
        );
      }
    }

    for (final b in scene.blobs) {
      final bx = ((b.xFrac + math.sin(t * b.speed + b.phase) * 0.06 * b.dir) % 1 + 1) % 1 * w;
      final by = b.yFrac * h;
      final r = b.rFrac * math.max(w, h);
      final warm = 1 - palette.daylight * 0.3;
      final blobColor = warm > 0.5 ? const Color(0xFFFFB482) : Colors.white;
      final rg = Paint()
        ..shader = RadialGradient(colors: [blobColor.withOpacity(0.16 * (0.4 + warm)), blobColor.withOpacity(0)])
            .createShader(Rect.fromCircle(center: Offset(bx, by), radius: r));
      canvas.drawCircle(Offset(bx, by), r, rg);
    }

    final baseY = h;
    final skylineH = h * 0.4;
    final silhouettePaint = Paint()..color = palette.silhouette;
    for (final b in scene.buildings) {
      final bx = b.xFrac * w;
      final bw = b.widthFrac * w;
      final bh = b.heightFrac * skylineH + skylineH * 0.3;
      canvas.drawRect(Rect.fromLTWH(bx, baseY - bh, bw, bh), silhouettePaint);
      if (b.lit && palette.daylight < 0.55) {
        final winAlpha = ((0.55 - palette.daylight) * 1.3).clamp(0.0, 1.0);
        final winPaint = Paint()..color = const Color(0xFFFFC978).withOpacity(winAlpha);
        for (var r = 0; r < b.litRows; r++) {
          final wy = baseY - bh + 6 + r * ((bh - 12) / b.litRows);
          for (var c = 2.0; c < bw - 2; c += 7) {
            if ((r + c.floor()) % 3 == 0) canvas.drawRect(Rect.fromLTWH(bx + c, wy, 2.2, 2.6), winPaint);
          }
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SceneBackgroundPainter oldDelegate) =>
      oldDelegate.tz != tz || oldDelegate.animationSeconds != animationSeconds;
}
