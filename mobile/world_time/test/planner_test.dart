import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:world_time/state/app_state.dart';
import 'package:world_time/widgets/planner_bar.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('dayDeltaLabel', () {
    test('null when both zones share the same calendar date', () {
      final at = DateTime.utc(2026, 11, 10, 12, 30); // 18:00 in Delhi
      expect(dayDeltaLabel('Europe/London', 'Asia/Kolkata', at), isNull);
    });

    test('+1 for a city already into tomorrow relative to the anchor', () {
      // Regression case found while testing the web version live: 23:00 in
      // Delhi is 02:30 the next day in Tokyo.
      final at = DateTime.utc(2026, 11, 10, 17, 30); // 23:00 in Delhi
      expect(dayDeltaLabel('Asia/Tokyo', 'Asia/Kolkata', at), '+1');
    });

    test('flips sign when the anchor itself is the city that is ahead', () {
      final at = DateTime.utc(2026, 11, 10, 17, 30);
      expect(dayDeltaLabel('Asia/Kolkata', 'Asia/Tokyo', at), '-1');
    });
  });

  group('AppState planner methods', () {
    // These exercise only the planner state machine, so the test
    // constructs AppState directly without calling init() — init() talks to
    // real geolocation/timezone platform channels that aren't available
    // under `flutter test`, and none of that is needed here: the planner
    // methods only ever touch `hero` (set directly below) and their own
    // planner* fields.
    late AppState app;
    setUp(() {
      app = AppState();
      app.hero = const HeroCity(name: 'Delhi', tz: 'Asia/Kolkata', source: HeroSource.manual);
    });

    test('enterPlanning defaults the anchor to the current hero city', () {
      app.enterPlanning();
      expect(app.planningActive, isTrue);
      expect(app.plannerAnchorTz, 'Asia/Kolkata');
      expect(app.plannerReferenceInstant, isNotNull);
    });

    test('enterPlanning(tz) anchors on an explicit city instead', () {
      app.enterPlanning('Asia/Tokyo');
      expect(app.plannerAnchorTz, 'Asia/Tokyo');
    });

    test('setPlannerTimeOfDay sets the anchor zone\'s wall-clock time', () {
      app.enterPlanning();
      app.setPlannerTimeOfDay(23, 0);
      final local = tz.TZDateTime.from(app.plannerReferenceInstant!, tz.getLocation('Asia/Kolkata'));
      expect(local.hour, 23);
      expect(local.minute, 0);
    });

    test('switching anchor keeps the same instant — other cities don\'t jump', () {
      app.enterPlanning();
      app.setPlannerTimeOfDay(23, 0);
      final instant = app.plannerReferenceInstant;
      app.setPlannerAnchor('Asia/Tokyo');
      expect(app.plannerAnchorTz, 'Asia/Tokyo');
      expect(app.plannerReferenceInstant, instant);
      final tokyo = tz.TZDateTime.from(app.plannerReferenceInstant!, tz.getLocation('Asia/Tokyo'));
      expect(tokyo.hour, 2);
      expect(tokyo.minute, 30);
    });

    test('shiftPlannerDay moves one calendar day, preserving the time-of-day', () {
      app.enterPlanning();
      app.setPlannerTimeOfDay(9, 15);
      final before = tz.TZDateTime.from(app.plannerReferenceInstant!, tz.getLocation('Asia/Kolkata'));
      app.shiftPlannerDay(1);
      final after = tz.TZDateTime.from(app.plannerReferenceInstant!, tz.getLocation('Asia/Kolkata'));
      expect(after.hour, before.hour);
      expect(after.minute, before.minute);
      expect(DateTime.utc(after.year, after.month, after.day).difference(DateTime.utc(before.year, before.month, before.day)).inDays, 1);
    });

    test('exitPlanning turns planning off', () {
      app.enterPlanning();
      app.exitPlanning();
      expect(app.planningActive, isFalse);
    });

    test('planner setters are no-ops while inactive', () {
      app.setPlannerTimeOfDay(10, 0);
      app.setPlannerAnchor('Asia/Tokyo');
      app.shiftPlannerDay(1);
      expect(app.plannerReferenceInstant, isNull);
      expect(app.plannerAnchorTz, isNull);
    });
  });

  group('PlannerBar widget', () {
    // Exercises the actual track widget end to end — tapping/dragging the
    // real rendered GestureDetector, not just calling AppState's methods
    // directly — since the bug class this guards against (a gesture that
    // silently never reaches its handler) would show up here, not in the
    // plain state-machine tests above.
    testWidgets('tapping near the left edge of the track sets an early time-of-day', (tester) async {
      final app = AppState();
      app.hero = const HeroCity(name: 'Delhi', tz: 'Asia/Kolkata', source: HeroSource.manual);
      app.enterPlanning();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: app,
          child: MaterialApp(
            home: Scaffold(
              body: PlannerBar(ink: Colors.black, inkDim: Colors.grey, accent: Colors.orange),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trackFinder = find.byKey(const Key('plannerTrack'));
      expect(trackFinder, findsOneWidget);
      final rect = tester.getRect(trackFinder);
      // 5% across the track — comfortably inside it, close to the left edge.
      final target = Offset(rect.left + rect.width * 0.05, rect.center.dy);

      await tester.tapAt(target);
      await tester.pumpAndSettle();

      final local = tz.TZDateTime.from(app.plannerReferenceInstant!, tz.getLocation('Asia/Kolkata'));
      expect(local.hour, lessThan(3));
    });

    testWidgets('dragging across the track moves the time forward', (tester) async {
      final app = AppState();
      app.hero = const HeroCity(name: 'Delhi', tz: 'Asia/Kolkata', source: HeroSource.manual);
      app.enterPlanning();
      app.setPlannerTimeOfDay(0, 0); // known starting point

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: app,
          child: MaterialApp(
            home: Scaffold(
              body: PlannerBar(ink: Colors.black, inkDim: Colors.grey, accent: Colors.orange),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.byKey(const Key('plannerTrack')));
      final start = Offset(rect.left + rect.width * 0.1, rect.center.dy);
      final end = Offset(rect.left + rect.width * 0.9, rect.center.dy);

      final gesture = await tester.startGesture(start);
      await gesture.moveTo(end);
      await gesture.up();
      await tester.pumpAndSettle();

      final local = tz.TZDateTime.from(app.plannerReferenceInstant!, tz.getLocation('Asia/Kolkata'));
      expect(local.hour, greaterThan(18));
    });
  });
}
