import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:world_time/data/cities_db.dart';
import 'package:world_time/widgets/city_ticker.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('cityForTimeZone overrides the display name for India\'s single zone', () {
    final delhi = cityForTimeZone('Asia/Kolkata');
    expect(delhi, isNotNull);
    expect(delhi!.name, 'Delhi');
  });

  test('nearestCity finds a close match near Paris', () {
    final match = nearestCity(48.85, 2.35);
    expect(match, isNotNull);
    expect(match!.city.tz, 'Europe/Paris');
    expect(match.distanceKm, lessThan(5));
  });

  test('default strip excludes the hero city', () {
    final strip = defaultStripTzs.where((tz) => tz != 'Asia/Kolkata').toList();
    expect(strip.contains('Asia/Kolkata'), isFalse);
    expect(strip.length, greaterThanOrEqualTo(4));
  });

  group('cityForTimeZone legacy IANA alias resolution', () {
    // Regression: a device reporting FlutterTimezone.getLocalTimezone() ==
    // "Asia/Calcutta" (observed on a real device in Delhi) used to miss the
    // curated dataset entirely and fall back to a raw-string label
    // ("Calcutta") instead of the intended "Delhi" override. Mirrors
    // web/test/cities-db.test.js's equivalent case.
    test('Asia/Calcutta resolves to the curated Delhi entry', () {
      final entry = cityForTimeZone('Asia/Calcutta');
      expect(entry, isNotNull);
      expect(entry!.name, 'Delhi');
      expect(entry.tz, 'Asia/Kolkata');
    });

    // Same bug class for Kyiv, which is in the default city strip.
    test('Europe/Kiev resolves to the curated Kyiv entry', () {
      final entry = cityForTimeZone('Europe/Kiev');
      expect(entry, isNotNull);
      expect(entry!.name, 'Kyiv');
      expect(entry.tz, 'Europe/Kyiv');
    });

    test('an unrecognized zone with no alias still resolves to null', () {
      expect(cityForTimeZone('Pacific/Not_A_Real_Zone'), isNull);
    });
  });

  group('CityTicker', () {
    const cities = [
      CityEntry(name: 'New York', tz: 'America/New_York', lat: 40.71, lon: -74.01),
      CityEntry(name: 'London', tz: 'Europe/London', lat: 51.51, lon: -0.13),
      CityEntry(name: 'Paris', tz: 'Europe/Paris', lat: 48.85, lon: 2.35),
      CityEntry(name: 'Kyiv', tz: 'Europe/Kyiv', lat: 50.45, lon: 30.52),
      CityEntry(name: 'Tokyo', tz: 'Asia/Tokyo', lat: 35.68, lon: 139.69),
    ];

    Future<void> pumpTicker(WidgetTester tester, double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: width,
            child: const CityTicker(cities: cities, ink: Colors.black, inkDim: Colors.grey),
          ),
        ),
      );
      await tester.pump();
    }

    // The web equivalent of this exact bug (a freshly built tile rendering
    // with no time text until a later tick) is what prompted this check —
    // Flutter's declarative rebuild doesn't have that failure mode, but
    // this locks the invariant in so a future refactor can't reintroduce it.
    testWidgets('every tile shows non-empty HH:MM text, scrolling case', (tester) async {
      await pumpTicker(tester, 200); // narrow: forces the scrolling/duplicate path
      final timeFinder = find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d{2}:\d{2}$').hasMatch(w.data ?? ''),
      );
      expect(timeFinder, findsAtLeastNWidgets(cities.length));
    });

    testWidgets('every tile shows non-empty HH:MM text, static case', (tester) async {
      await pumpTicker(tester, 2000); // wide: everything fits in one pass
      final timeFinder = find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d{2}:\d{2}$').hasMatch(w.data ?? ''),
      );
      expect(timeFinder, findsNWidgets(cities.length));
    });
  });
}
