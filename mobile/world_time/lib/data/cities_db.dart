import 'dart:math' as math;

/// Curated world-city dataset: display name + IANA timezone + approximate
/// city-center lat/lon. Ported 1:1 from web/cities-db.js so both the
/// screensavers and this app agree on display names (e.g. "Delhi" for the
/// IANA zone Asia/Kolkata) and reverse-geocoding behavior.
class CityEntry {
  final String name;
  final String tz;
  final double lat;
  final double lon;

  const CityEntry({
    required this.name,
    required this.tz,
    required this.lat,
    required this.lon,
  });
}

class CityMatch {
  final CityEntry city;
  final double distanceKm;
  const CityMatch(this.city, this.distanceKm);
}

const List<CityEntry> citiesDb = [
  // North America
  CityEntry(name: "New York", tz: "America/New_York", lat: 40.71, lon: -74.01),
  CityEntry(name: "Los Angeles", tz: "America/Los_Angeles", lat: 34.05, lon: -118.24),
  CityEntry(name: "San Francisco", tz: "America/Los_Angeles", lat: 37.77, lon: -122.42),
  CityEntry(name: "Chicago", tz: "America/Chicago", lat: 41.88, lon: -87.63),
  CityEntry(name: "Houston", tz: "America/Chicago", lat: 29.76, lon: -95.37),
  CityEntry(name: "Dallas", tz: "America/Chicago", lat: 32.78, lon: -96.80),
  CityEntry(name: "Phoenix", tz: "America/Phoenix", lat: 33.45, lon: -112.07),
  CityEntry(name: "Denver", tz: "America/Denver", lat: 39.74, lon: -104.99),
  CityEntry(name: "Seattle", tz: "America/Los_Angeles", lat: 47.61, lon: -122.33),
  CityEntry(name: "Miami", tz: "America/New_York", lat: 25.76, lon: -80.19),
  CityEntry(name: "Boston", tz: "America/New_York", lat: 42.36, lon: -71.06),
  CityEntry(name: "Washington, D.C.", tz: "America/New_York", lat: 38.90, lon: -77.04),
  CityEntry(name: "Toronto", tz: "America/Toronto", lat: 43.65, lon: -79.38),
  CityEntry(name: "Vancouver", tz: "America/Vancouver", lat: 49.28, lon: -123.12),
  CityEntry(name: "Montreal", tz: "America/Toronto", lat: 45.50, lon: -73.57),
  CityEntry(name: "Mexico City", tz: "America/Mexico_City", lat: 19.43, lon: -99.13),
  CityEntry(name: "Honolulu", tz: "Pacific/Honolulu", lat: 21.31, lon: -157.86),
  CityEntry(name: "Anchorage", tz: "America/Anchorage", lat: 61.22, lon: -149.90),
  CityEntry(name: "Atlanta", tz: "America/New_York", lat: 33.75, lon: -84.39),
  CityEntry(name: "Las Vegas", tz: "America/Los_Angeles", lat: 36.17, lon: -115.14),
  CityEntry(name: "Minneapolis", tz: "America/Chicago", lat: 44.98, lon: -93.27),
  CityEntry(name: "Detroit", tz: "America/New_York", lat: 42.33, lon: -83.05),
  CityEntry(name: "Philadelphia", tz: "America/New_York", lat: 39.95, lon: -75.17),
  CityEntry(name: "Austin", tz: "America/Chicago", lat: 30.27, lon: -97.74),
  CityEntry(name: "San Diego", tz: "America/Los_Angeles", lat: 32.72, lon: -117.16),

  // Central America / Caribbean
  CityEntry(name: "Havana", tz: "America/Havana", lat: 23.13, lon: -82.38),
  CityEntry(name: "Panama City", tz: "America/Panama", lat: 8.98, lon: -79.52),
  CityEntry(name: "San Jose", tz: "America/Costa_Rica", lat: 9.93, lon: -84.08),
  CityEntry(name: "Kingston", tz: "America/Jamaica", lat: 17.97, lon: -76.79),
  CityEntry(name: "Santo Domingo", tz: "America/Santo_Domingo", lat: 18.49, lon: -69.94),

  // South America
  CityEntry(name: "Sao Paulo", tz: "America/Sao_Paulo", lat: -23.55, lon: -46.63),
  CityEntry(name: "Rio de Janeiro", tz: "America/Sao_Paulo", lat: -22.91, lon: -43.17),
  CityEntry(name: "Buenos Aires", tz: "America/Argentina/Buenos_Aires", lat: -34.60, lon: -58.38),
  CityEntry(name: "Santiago", tz: "America/Santiago", lat: -33.45, lon: -70.67),
  CityEntry(name: "Lima", tz: "America/Lima", lat: -12.05, lon: -77.04),
  CityEntry(name: "Bogota", tz: "America/Bogota", lat: 4.71, lon: -74.07),
  CityEntry(name: "Caracas", tz: "America/Caracas", lat: 10.48, lon: -66.90),
  CityEntry(name: "Montevideo", tz: "America/Montevideo", lat: -34.90, lon: -56.16),
  CityEntry(name: "Quito", tz: "America/Guayaquil", lat: -0.18, lon: -78.47),

  // Europe
  CityEntry(name: "London", tz: "Europe/London", lat: 51.51, lon: -0.13),
  CityEntry(name: "Paris", tz: "Europe/Paris", lat: 48.85, lon: 2.35),
  CityEntry(name: "Berlin", tz: "Europe/Berlin", lat: 52.52, lon: 13.40),
  CityEntry(name: "Madrid", tz: "Europe/Madrid", lat: 40.42, lon: -3.70),
  CityEntry(name: "Rome", tz: "Europe/Rome", lat: 41.90, lon: 12.50),
  CityEntry(name: "Amsterdam", tz: "Europe/Amsterdam", lat: 52.37, lon: 4.90),
  CityEntry(name: "Zurich", tz: "Europe/Zurich", lat: 47.38, lon: 8.54),
  CityEntry(name: "Geneva", tz: "Europe/Zurich", lat: 46.20, lon: 6.14),
  CityEntry(name: "Vienna", tz: "Europe/Vienna", lat: 48.21, lon: 16.37),
  CityEntry(name: "Stockholm", tz: "Europe/Stockholm", lat: 59.33, lon: 18.07),
  CityEntry(name: "Oslo", tz: "Europe/Oslo", lat: 59.91, lon: 10.75),
  CityEntry(name: "Copenhagen", tz: "Europe/Copenhagen", lat: 55.68, lon: 12.57),
  CityEntry(name: "Helsinki", tz: "Europe/Helsinki", lat: 60.17, lon: 24.94),
  CityEntry(name: "Dublin", tz: "Europe/Dublin", lat: 53.35, lon: -6.26),
  CityEntry(name: "Lisbon", tz: "Europe/Lisbon", lat: 38.72, lon: -9.14),
  CityEntry(name: "Brussels", tz: "Europe/Brussels", lat: 50.85, lon: 4.35),
  CityEntry(name: "Warsaw", tz: "Europe/Warsaw", lat: 52.23, lon: 21.01),
  CityEntry(name: "Prague", tz: "Europe/Prague", lat: 50.08, lon: 14.44),
  CityEntry(name: "Budapest", tz: "Europe/Budapest", lat: 47.50, lon: 19.04),
  CityEntry(name: "Athens", tz: "Europe/Athens", lat: 37.98, lon: 23.73),
  CityEntry(name: "Kyiv", tz: "Europe/Kyiv", lat: 50.45, lon: 30.52),
  CityEntry(name: "Moscow", tz: "Europe/Moscow", lat: 55.76, lon: 37.62),
  CityEntry(name: "Istanbul", tz: "Europe/Istanbul", lat: 41.01, lon: 28.98),
  CityEntry(name: "Bucharest", tz: "Europe/Bucharest", lat: 44.43, lon: 26.10),
  CityEntry(name: "Sofia", tz: "Europe/Sofia", lat: 42.70, lon: 23.32),
  CityEntry(name: "Belgrade", tz: "Europe/Belgrade", lat: 44.79, lon: 20.45),
  CityEntry(name: "Zagreb", tz: "Europe/Zagreb", lat: 45.81, lon: 15.98),
  CityEntry(name: "Milan", tz: "Europe/Rome", lat: 45.46, lon: 9.19),
  CityEntry(name: "Munich", tz: "Europe/Berlin", lat: 48.14, lon: 11.58),
  CityEntry(name: "Barcelona", tz: "Europe/Madrid", lat: 41.39, lon: 2.17),
  CityEntry(name: "Edinburgh", tz: "Europe/London", lat: 55.95, lon: -3.19),
  CityEntry(name: "Reykjavik", tz: "Atlantic/Reykjavik", lat: 64.15, lon: -21.94),

  // Africa
  CityEntry(name: "Cairo", tz: "Africa/Cairo", lat: 30.04, lon: 31.24),
  CityEntry(name: "Lagos", tz: "Africa/Lagos", lat: 6.52, lon: 3.38),
  CityEntry(name: "Nairobi", tz: "Africa/Nairobi", lat: -1.29, lon: 36.82),
  CityEntry(name: "Johannesburg", tz: "Africa/Johannesburg", lat: -26.20, lon: 28.05),
  CityEntry(name: "Cape Town", tz: "Africa/Johannesburg", lat: -33.92, lon: 18.42),
  CityEntry(name: "Casablanca", tz: "Africa/Casablanca", lat: 33.57, lon: -7.59),
  CityEntry(name: "Addis Ababa", tz: "Africa/Addis_Ababa", lat: 9.03, lon: 38.74),
  CityEntry(name: "Accra", tz: "Africa/Accra", lat: 5.60, lon: -0.19),
  CityEntry(name: "Tunis", tz: "Africa/Tunis", lat: 36.81, lon: 10.18),
  CityEntry(name: "Algiers", tz: "Africa/Algiers", lat: 36.75, lon: 3.06),
  CityEntry(name: "Khartoum", tz: "Africa/Khartoum", lat: 15.50, lon: 32.56),
  CityEntry(name: "Dakar", tz: "Africa/Dakar", lat: 14.69, lon: -17.45),
  CityEntry(name: "Kinshasa", tz: "Africa/Kinshasa", lat: -4.44, lon: 15.27),

  // Middle East
  CityEntry(name: "Dubai", tz: "Asia/Dubai", lat: 25.20, lon: 55.27),
  CityEntry(name: "Abu Dhabi", tz: "Asia/Dubai", lat: 24.47, lon: 54.37),
  CityEntry(name: "Doha", tz: "Asia/Qatar", lat: 25.29, lon: 51.53),
  CityEntry(name: "Riyadh", tz: "Asia/Riyadh", lat: 24.71, lon: 46.68),
  CityEntry(name: "Jeddah", tz: "Asia/Riyadh", lat: 21.54, lon: 39.17),
  CityEntry(name: "Tel Aviv", tz: "Asia/Jerusalem", lat: 32.08, lon: 34.78),
  CityEntry(name: "Jerusalem", tz: "Asia/Jerusalem", lat: 31.77, lon: 35.21),
  CityEntry(name: "Amman", tz: "Asia/Amman", lat: 31.95, lon: 35.93),
  CityEntry(name: "Beirut", tz: "Asia/Beirut", lat: 33.89, lon: 35.50),
  CityEntry(name: "Baghdad", tz: "Asia/Baghdad", lat: 33.31, lon: 44.36),
  CityEntry(name: "Tehran", tz: "Asia/Tehran", lat: 35.69, lon: 51.39),
  CityEntry(name: "Kuwait City", tz: "Asia/Kuwait", lat: 29.38, lon: 47.98),
  CityEntry(name: "Muscat", tz: "Asia/Muscat", lat: 23.59, lon: 58.41),

  // South Asia — note: the IANA tz for all of India is Asia/Kolkata; there
  // is no Asia/Delhi. "Delhi" here is a display-name override only.
  CityEntry(name: "Delhi", tz: "Asia/Kolkata", lat: 28.61, lon: 77.21),
  CityEntry(name: "Mumbai", tz: "Asia/Kolkata", lat: 19.08, lon: 72.88),
  CityEntry(name: "Bangalore", tz: "Asia/Kolkata", lat: 12.97, lon: 77.59),
  CityEntry(name: "Kolkata", tz: "Asia/Kolkata", lat: 22.57, lon: 88.36),
  CityEntry(name: "Chennai", tz: "Asia/Kolkata", lat: 13.08, lon: 80.27),
  CityEntry(name: "Hyderabad", tz: "Asia/Kolkata", lat: 17.39, lon: 78.49),
  CityEntry(name: "Karachi", tz: "Asia/Karachi", lat: 24.86, lon: 67.01),
  CityEntry(name: "Lahore", tz: "Asia/Karachi", lat: 31.55, lon: 74.34),
  CityEntry(name: "Islamabad", tz: "Asia/Karachi", lat: 33.68, lon: 73.05),
  CityEntry(name: "Dhaka", tz: "Asia/Dhaka", lat: 23.81, lon: 90.41),
  CityEntry(name: "Kathmandu", tz: "Asia/Kathmandu", lat: 27.72, lon: 85.32),
  CityEntry(name: "Colombo", tz: "Asia/Colombo", lat: 6.93, lon: 79.85),

  // East Asia
  CityEntry(name: "Tokyo", tz: "Asia/Tokyo", lat: 35.68, lon: 139.69),
  CityEntry(name: "Osaka", tz: "Asia/Tokyo", lat: 34.69, lon: 135.50),
  CityEntry(name: "Seoul", tz: "Asia/Seoul", lat: 37.57, lon: 126.98),
  CityEntry(name: "Beijing", tz: "Asia/Shanghai", lat: 39.90, lon: 116.41),
  CityEntry(name: "Shanghai", tz: "Asia/Shanghai", lat: 31.23, lon: 121.47),
  CityEntry(name: "Shenzhen", tz: "Asia/Shanghai", lat: 22.54, lon: 114.06),
  CityEntry(name: "Hong Kong", tz: "Asia/Hong_Kong", lat: 22.32, lon: 114.17),
  CityEntry(name: "Taipei", tz: "Asia/Taipei", lat: 25.03, lon: 121.57),
  CityEntry(name: "Macau", tz: "Asia/Macau", lat: 22.20, lon: 113.54),
  CityEntry(name: "Ulaanbaatar", tz: "Asia/Ulaanbaatar", lat: 47.89, lon: 106.91),

  // Southeast Asia
  CityEntry(name: "Singapore", tz: "Asia/Singapore", lat: 1.35, lon: 103.82),
  CityEntry(name: "Bangkok", tz: "Asia/Bangkok", lat: 13.76, lon: 100.50),
  CityEntry(name: "Jakarta", tz: "Asia/Jakarta", lat: -6.21, lon: 106.85),
  CityEntry(name: "Manila", tz: "Asia/Manila", lat: 14.60, lon: 120.98),
  CityEntry(name: "Kuala Lumpur", tz: "Asia/Kuala_Lumpur", lat: 3.14, lon: 101.69),
  CityEntry(name: "Ho Chi Minh City", tz: "Asia/Ho_Chi_Minh", lat: 10.78, lon: 106.70),
  CityEntry(name: "Hanoi", tz: "Asia/Ho_Chi_Minh", lat: 21.03, lon: 105.85),
  CityEntry(name: "Phnom Penh", tz: "Asia/Phnom_Penh", lat: 11.56, lon: 104.92),
  CityEntry(name: "Yangon", tz: "Asia/Yangon", lat: 16.87, lon: 96.20),

  // Oceania
  CityEntry(name: "Sydney", tz: "Australia/Sydney", lat: -33.87, lon: 151.21),
  CityEntry(name: "Melbourne", tz: "Australia/Melbourne", lat: -37.81, lon: 144.96),
  CityEntry(name: "Brisbane", tz: "Australia/Brisbane", lat: -27.47, lon: 153.03),
  CityEntry(name: "Perth", tz: "Australia/Perth", lat: -31.95, lon: 115.86),
  CityEntry(name: "Adelaide", tz: "Australia/Adelaide", lat: -34.93, lon: 138.60),
  CityEntry(name: "Auckland", tz: "Pacific/Auckland", lat: -36.85, lon: 174.76),
  CityEntry(name: "Wellington", tz: "Pacific/Auckland", lat: -41.29, lon: 174.78),
  CityEntry(name: "Suva", tz: "Pacific/Fiji", lat: -18.14, lon: 178.44),
];

/// The 4-6 city strip shown when no saved preference exists yet.
const List<String> defaultStripTzs = [
  "Asia/Kolkata", // Delhi
  "America/New_York", // New York
  "Europe/London", // London
  "Europe/Paris", // Paris
  "Europe/Kyiv", // Kyiv
  "Asia/Tokyo", // Tokyo
];

double _toRad(double deg) => deg * math.pi / 180;

/// Great-circle distance in km (haversine) — accurate enough for a
/// ~140-city nearest-match.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Nearest dataset entry to a coordinate — the on-device "reverse geocode".
CityMatch? nearestCity(double lat, double lon) {
  CityEntry? best;
  double bestDist = double.infinity;
  for (final city in citiesDb) {
    final d = haversineKm(lat, lon, city.lat, city.lon);
    if (d < bestDist) {
      bestDist = d;
      best = city;
    }
  }
  return best == null ? null : CityMatch(best, bestDist);
}

/// Dataset entry for an IANA zone, if one is curated (for display-name
/// overrides, e.g. "Delhi" for Asia/Kolkata).
CityEntry? cityForTimeZone(String tz) {
  for (final c in citiesDb) {
    if (c.tz == tz) return c;
  }
  return null;
}

/// Last-resort label for a timezone with no curated dataset entry.
String friendlyNameFromTz(String tz) {
  final last = tz.contains("/") ? tz.split("/").last : tz;
  return last.replaceAll("_", " ");
}

String cityNameForTz(String tz) => cityForTimeZone(tz)?.name ?? friendlyNameFromTz(tz);
