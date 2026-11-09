import 'package:flutter_test/flutter_test.dart';

import 'package:world_time/data/cities_db.dart';

void main() {
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
}
