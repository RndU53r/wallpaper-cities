"use strict";

/*
 * Curated world-city dataset: display name + IANA timezone + approximate
 * city-center lat/lon. This is the single source of truth for:
 *   - display-name overrides (e.g. "Delhi" for the IANA zone Asia/Kolkata —
 *     there is no Asia/Delhi),
 *   - on-device reverse geocoding (nearest entry to a coarse lat/lon fix,
 *     no network call),
 *   - the default city strip.
 *
 * Coordinates are city-center approximations — plenty precise for "nearest
 * supported city" matching at this scale (entries are tens to hundreds of
 * km apart almost everywhere), not meant for anything finer-grained.
 */

const CITIES_DB = [
  // North America
  { name: "New York", tz: "America/New_York", lat: 40.71, lon: -74.01 },
  { name: "Los Angeles", tz: "America/Los_Angeles", lat: 34.05, lon: -118.24 },
  { name: "San Francisco", tz: "America/Los_Angeles", lat: 37.77, lon: -122.42 },
  { name: "Chicago", tz: "America/Chicago", lat: 41.88, lon: -87.63 },
  { name: "Houston", tz: "America/Chicago", lat: 29.76, lon: -95.37 },
  { name: "Dallas", tz: "America/Chicago", lat: 32.78, lon: -96.80 },
  { name: "Phoenix", tz: "America/Phoenix", lat: 33.45, lon: -112.07 },
  { name: "Denver", tz: "America/Denver", lat: 39.74, lon: -104.99 },
  { name: "Seattle", tz: "America/Los_Angeles", lat: 47.61, lon: -122.33 },
  { name: "Miami", tz: "America/New_York", lat: 25.76, lon: -80.19 },
  { name: "Boston", tz: "America/New_York", lat: 42.36, lon: -71.06 },
  { name: "Washington, D.C.", tz: "America/New_York", lat: 38.90, lon: -77.04 },
  { name: "Toronto", tz: "America/Toronto", lat: 43.65, lon: -79.38 },
  { name: "Vancouver", tz: "America/Vancouver", lat: 49.28, lon: -123.12 },
  { name: "Montreal", tz: "America/Toronto", lat: 45.50, lon: -73.57 },
  { name: "Mexico City", tz: "America/Mexico_City", lat: 19.43, lon: -99.13 },
  { name: "Honolulu", tz: "Pacific/Honolulu", lat: 21.31, lon: -157.86 },
  { name: "Anchorage", tz: "America/Anchorage", lat: 61.22, lon: -149.90 },
  { name: "Atlanta", tz: "America/New_York", lat: 33.75, lon: -84.39 },
  { name: "Las Vegas", tz: "America/Los_Angeles", lat: 36.17, lon: -115.14 },
  { name: "Minneapolis", tz: "America/Chicago", lat: 44.98, lon: -93.27 },
  { name: "Detroit", tz: "America/New_York", lat: 42.33, lon: -83.05 },
  { name: "Philadelphia", tz: "America/New_York", lat: 39.95, lon: -75.17 },
  { name: "Austin", tz: "America/Chicago", lat: 30.27, lon: -97.74 },
  { name: "San Diego", tz: "America/Los_Angeles", lat: 32.72, lon: -117.16 },

  // Central America / Caribbean
  { name: "Havana", tz: "America/Havana", lat: 23.13, lon: -82.38 },
  { name: "Panama City", tz: "America/Panama", lat: 8.98, lon: -79.52 },
  { name: "San Jose", tz: "America/Costa_Rica", lat: 9.93, lon: -84.08 },
  { name: "Kingston", tz: "America/Jamaica", lat: 17.97, lon: -76.79 },
  { name: "Santo Domingo", tz: "America/Santo_Domingo", lat: 18.49, lon: -69.94 },

  // South America
  { name: "Sao Paulo", tz: "America/Sao_Paulo", lat: -23.55, lon: -46.63 },
  { name: "Rio de Janeiro", tz: "America/Sao_Paulo", lat: -22.91, lon: -43.17 },
  { name: "Buenos Aires", tz: "America/Argentina/Buenos_Aires", lat: -34.60, lon: -58.38 },
  { name: "Santiago", tz: "America/Santiago", lat: -33.45, lon: -70.67 },
  { name: "Lima", tz: "America/Lima", lat: -12.05, lon: -77.04 },
  { name: "Bogota", tz: "America/Bogota", lat: 4.71, lon: -74.07 },
  { name: "Caracas", tz: "America/Caracas", lat: 10.48, lon: -66.90 },
  { name: "Montevideo", tz: "America/Montevideo", lat: -34.90, lon: -56.16 },
  { name: "Quito", tz: "America/Guayaquil", lat: -0.18, lon: -78.47 },

  // Europe
  { name: "London", tz: "Europe/London", lat: 51.51, lon: -0.13 },
  { name: "Paris", tz: "Europe/Paris", lat: 48.85, lon: 2.35 },
  { name: "Berlin", tz: "Europe/Berlin", lat: 52.52, lon: 13.40 },
  { name: "Madrid", tz: "Europe/Madrid", lat: 40.42, lon: -3.70 },
  { name: "Rome", tz: "Europe/Rome", lat: 41.90, lon: 12.50 },
  { name: "Amsterdam", tz: "Europe/Amsterdam", lat: 52.37, lon: 4.90 },
  { name: "Zurich", tz: "Europe/Zurich", lat: 47.38, lon: 8.54 },
  { name: "Geneva", tz: "Europe/Zurich", lat: 46.20, lon: 6.14 },
  { name: "Vienna", tz: "Europe/Vienna", lat: 48.21, lon: 16.37 },
  { name: "Stockholm", tz: "Europe/Stockholm", lat: 59.33, lon: 18.07 },
  { name: "Oslo", tz: "Europe/Oslo", lat: 59.91, lon: 10.75 },
  { name: "Copenhagen", tz: "Europe/Copenhagen", lat: 55.68, lon: 12.57 },
  { name: "Helsinki", tz: "Europe/Helsinki", lat: 60.17, lon: 24.94 },
  { name: "Dublin", tz: "Europe/Dublin", lat: 53.35, lon: -6.26 },
  { name: "Lisbon", tz: "Europe/Lisbon", lat: 38.72, lon: -9.14 },
  { name: "Brussels", tz: "Europe/Brussels", lat: 50.85, lon: 4.35 },
  { name: "Warsaw", tz: "Europe/Warsaw", lat: 52.23, lon: 21.01 },
  { name: "Prague", tz: "Europe/Prague", lat: 50.08, lon: 14.44 },
  { name: "Budapest", tz: "Europe/Budapest", lat: 47.50, lon: 19.04 },
  { name: "Athens", tz: "Europe/Athens", lat: 37.98, lon: 23.73 },
  { name: "Kyiv", tz: "Europe/Kyiv", lat: 50.45, lon: 30.52 },
  { name: "Moscow", tz: "Europe/Moscow", lat: 55.76, lon: 37.62 },
  { name: "Istanbul", tz: "Europe/Istanbul", lat: 41.01, lon: 28.98 },
  { name: "Bucharest", tz: "Europe/Bucharest", lat: 44.43, lon: 26.10 },
  { name: "Sofia", tz: "Europe/Sofia", lat: 42.70, lon: 23.32 },
  { name: "Belgrade", tz: "Europe/Belgrade", lat: 44.79, lon: 20.45 },
  { name: "Zagreb", tz: "Europe/Zagreb", lat: 45.81, lon: 15.98 },
  { name: "Milan", tz: "Europe/Rome", lat: 45.46, lon: 9.19 },
  { name: "Munich", tz: "Europe/Berlin", lat: 48.14, lon: 11.58 },
  { name: "Barcelona", tz: "Europe/Madrid", lat: 41.39, lon: 2.17 },
  { name: "Edinburgh", tz: "Europe/London", lat: 55.95, lon: -3.19 },
  { name: "Reykjavik", tz: "Atlantic/Reykjavik", lat: 64.15, lon: -21.94 },

  // Africa
  { name: "Cairo", tz: "Africa/Cairo", lat: 30.04, lon: 31.24 },
  { name: "Lagos", tz: "Africa/Lagos", lat: 6.52, lon: 3.38 },
  { name: "Nairobi", tz: "Africa/Nairobi", lat: -1.29, lon: 36.82 },
  { name: "Johannesburg", tz: "Africa/Johannesburg", lat: -26.20, lon: 28.05 },
  { name: "Cape Town", tz: "Africa/Johannesburg", lat: -33.92, lon: 18.42 },
  { name: "Casablanca", tz: "Africa/Casablanca", lat: 33.57, lon: -7.59 },
  { name: "Addis Ababa", tz: "Africa/Addis_Ababa", lat: 9.03, lon: 38.74 },
  { name: "Accra", tz: "Africa/Accra", lat: 5.60, lon: -0.19 },
  { name: "Tunis", tz: "Africa/Tunis", lat: 36.81, lon: 10.18 },
  { name: "Algiers", tz: "Africa/Algiers", lat: 36.75, lon: 3.06 },
  { name: "Khartoum", tz: "Africa/Khartoum", lat: 15.50, lon: 32.56 },
  { name: "Dakar", tz: "Africa/Dakar", lat: 14.69, lon: -17.45 },
  { name: "Kinshasa", tz: "Africa/Kinshasa", lat: -4.44, lon: 15.27 },

  // Middle East
  { name: "Dubai", tz: "Asia/Dubai", lat: 25.20, lon: 55.27 },
  { name: "Abu Dhabi", tz: "Asia/Dubai", lat: 24.47, lon: 54.37 },
  { name: "Doha", tz: "Asia/Qatar", lat: 25.29, lon: 51.53 },
  { name: "Riyadh", tz: "Asia/Riyadh", lat: 24.71, lon: 46.68 },
  { name: "Jeddah", tz: "Asia/Riyadh", lat: 21.54, lon: 39.17 },
  { name: "Tel Aviv", tz: "Asia/Jerusalem", lat: 32.08, lon: 34.78 },
  { name: "Jerusalem", tz: "Asia/Jerusalem", lat: 31.77, lon: 35.21 },
  { name: "Amman", tz: "Asia/Amman", lat: 31.95, lon: 35.93 },
  { name: "Beirut", tz: "Asia/Beirut", lat: 33.89, lon: 35.50 },
  { name: "Baghdad", tz: "Asia/Baghdad", lat: 33.31, lon: 44.36 },
  { name: "Tehran", tz: "Asia/Tehran", lat: 35.69, lon: 51.39 },
  { name: "Kuwait City", tz: "Asia/Kuwait", lat: 29.38, lon: 47.98 },
  { name: "Muscat", tz: "Asia/Muscat", lat: 23.59, lon: 58.41 },

  // South Asia — note: the IANA tz for all of India is Asia/Kolkata; there
  // is no Asia/Delhi. "Delhi" here is a display-name override only.
  { name: "Delhi", tz: "Asia/Kolkata", lat: 28.61, lon: 77.21 },
  { name: "Mumbai", tz: "Asia/Kolkata", lat: 19.08, lon: 72.88 },
  { name: "Bangalore", tz: "Asia/Kolkata", lat: 12.97, lon: 77.59 },
  { name: "Kolkata", tz: "Asia/Kolkata", lat: 22.57, lon: 88.36 },
  { name: "Chennai", tz: "Asia/Kolkata", lat: 13.08, lon: 80.27 },
  { name: "Hyderabad", tz: "Asia/Kolkata", lat: 17.39, lon: 78.49 },
  { name: "Karachi", tz: "Asia/Karachi", lat: 24.86, lon: 67.01 },
  { name: "Lahore", tz: "Asia/Karachi", lat: 31.55, lon: 74.34 },
  { name: "Islamabad", tz: "Asia/Karachi", lat: 33.68, lon: 73.05 },
  { name: "Dhaka", tz: "Asia/Dhaka", lat: 23.81, lon: 90.41 },
  { name: "Kathmandu", tz: "Asia/Kathmandu", lat: 27.72, lon: 85.32 },
  { name: "Colombo", tz: "Asia/Colombo", lat: 6.93, lon: 79.85 },

  // East Asia
  { name: "Tokyo", tz: "Asia/Tokyo", lat: 35.68, lon: 139.69 },
  { name: "Osaka", tz: "Asia/Tokyo", lat: 34.69, lon: 135.50 },
  { name: "Seoul", tz: "Asia/Seoul", lat: 37.57, lon: 126.98 },
  { name: "Beijing", tz: "Asia/Shanghai", lat: 39.90, lon: 116.41 },
  { name: "Shanghai", tz: "Asia/Shanghai", lat: 31.23, lon: 121.47 },
  { name: "Shenzhen", tz: "Asia/Shanghai", lat: 22.54, lon: 114.06 },
  { name: "Hong Kong", tz: "Asia/Hong_Kong", lat: 22.32, lon: 114.17 },
  { name: "Taipei", tz: "Asia/Taipei", lat: 25.03, lon: 121.57 },
  { name: "Macau", tz: "Asia/Macau", lat: 22.20, lon: 113.54 },
  { name: "Ulaanbaatar", tz: "Asia/Ulaanbaatar", lat: 47.89, lon: 106.91 },

  // Southeast Asia
  { name: "Singapore", tz: "Asia/Singapore", lat: 1.35, lon: 103.82 },
  { name: "Bangkok", tz: "Asia/Bangkok", lat: 13.76, lon: 100.50 },
  { name: "Jakarta", tz: "Asia/Jakarta", lat: -6.21, lon: 106.85 },
  { name: "Manila", tz: "Asia/Manila", lat: 14.60, lon: 120.98 },
  { name: "Kuala Lumpur", tz: "Asia/Kuala_Lumpur", lat: 3.14, lon: 101.69 },
  { name: "Ho Chi Minh City", tz: "Asia/Ho_Chi_Minh", lat: 10.78, lon: 106.70 },
  { name: "Hanoi", tz: "Asia/Ho_Chi_Minh", lat: 21.03, lon: 105.85 },
  { name: "Phnom Penh", tz: "Asia/Phnom_Penh", lat: 11.56, lon: 104.92 },
  { name: "Yangon", tz: "Asia/Yangon", lat: 16.87, lon: 96.20 },

  // Oceania
  { name: "Sydney", tz: "Australia/Sydney", lat: -33.87, lon: 151.21 },
  { name: "Melbourne", tz: "Australia/Melbourne", lat: -37.81, lon: 144.96 },
  { name: "Brisbane", tz: "Australia/Brisbane", lat: -27.47, lon: 153.03 },
  { name: "Perth", tz: "Australia/Perth", lat: -31.95, lon: 115.86 },
  { name: "Adelaide", tz: "Australia/Adelaide", lat: -34.93, lon: 138.60 },
  { name: "Auckland", tz: "Pacific/Auckland", lat: -36.85, lon: 174.76 },
  { name: "Wellington", tz: "Pacific/Auckland", lat: -41.29, lon: 174.78 },
  { name: "Suva", tz: "Pacific/Fiji", lat: -18.14, lon: 178.44 },
];

/** The 4–6 city strip shown when no saved preference exists yet. */
const DEFAULT_STRIP_TZS = [
  "Asia/Kolkata",       // Delhi
  "America/New_York",   // New York
  "Europe/London",      // London
  "Europe/Paris",       // Paris
  "Europe/Kyiv",        // Kyiv
  "Asia/Tokyo",         // Tokyo
];

/** Great-circle distance in km (haversine) — accurate enough for a ~140-city nearest-match. */
function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
}

/** Nearest dataset entry to a coordinate — the on-device "reverse geocode". */
function nearestCity(lat, lon) {
  let best = null;
  let bestDist = Infinity;
  for (const city of CITIES_DB) {
    const d = haversineKm(lat, lon, city.lat, city.lon);
    if (d < bestDist) { bestDist = d; best = city; }
  }
  return best ? { ...best, distanceKm: bestDist } : null;
}

/** Dataset entry for an IANA zone, if one is curated (for display-name overrides). */
function cityForTimeZone(tz) {
  return CITIES_DB.find((c) => c.tz === tz) || null;
}
