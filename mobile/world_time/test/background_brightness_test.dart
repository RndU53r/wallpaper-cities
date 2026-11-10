import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_time/widgets/background_brightness.dart';

Uint8List solidPixels(int r, int g, int b, int width, int height) {
  final data = Uint8List(width * height * 4);
  for (var i = 0; i < data.length; i += 4) {
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
    data[i + 3] = 255;
  }
  return data;
}

void main() {
  group('isBottomStripDark', () {
    // Regression: the ticker used to always use the Day/Night chrome
    // theme's own ink color, which could land near-black text over a dark
    // user-supplied monument photo regardless of this sample. Mirrors
    // web/test/scene-contrast.test.js's equivalent coverage.
    test('true for a uniformly dark image', () {
      final pixels = solidPixels(10, 10, 10, 20, 20);
      expect(isBottomStripDark(pixels, 20, 20), isTrue);
    });

    test('false for a uniformly bright image', () {
      final pixels = solidPixels(240, 235, 225, 20, 20);
      expect(isBottomStripDark(pixels, 20, 20), isFalse);
    });

    test('only the bottom strip matters — a bright top with a dark bottom reads as dark', () {
      final width = 10, height = 20;
      final data = Uint8List(width * height * 4);
      for (var y = 0; y < height; y++) {
        final dark = y >= (height * 0.82).floor();
        for (var x = 0; x < width; x++) {
          final i = (y * width + x) * 4;
          final v = dark ? 10 : 250;
          data[i] = v;
          data[i + 1] = v;
          data[i + 2] = v;
          data[i + 3] = 255;
        }
      }
      expect(isBottomStripDark(data, width, height), isTrue);
    });

    test('does not throw on a zero-size image', () {
      expect(() => isBottomStripDark(Uint8List(0), 0, 0), returnsNormally);
      expect(isBottomStripDark(Uint8List(0), 0, 0), isTrue);
    });
  });
}
