import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cities_db.dart';

enum HeroSource { manual, geo, deviceTz }

class HeroCity {
  final String name;
  final String tz;
  final HeroSource source;
  const HeroCity({required this.name, required this.tz, required this.source});
}

enum AppThemeMode { auto, system, day, night }

/// Central app state: hero city resolution (geolocation -> on-device reverse
/// geocode -> device timezone -> manual override), the 4-6 city strip, and
/// the UI theme mode. Mirrors web/app.js's Hero/Cities/Theme modules so both
/// the shared web Motion UI and this native app agree on behavior.
class AppState extends ChangeNotifier {
  static const _cityStorageKey = 'worldtime.cities.v1';
  static const _heroOverrideKey = 'worldtime.heroOverride.v1';
  static const _themeStorageKey = 'worldtime.theme.v1';
  static const _monumentStorageKey = 'worldtime.monuments.v1';
  static const minCities = 4;
  static const maxCities = 6;
  static const _geoMaxUsefulKm = 300.0;
  static const _geoRecheckInterval = Duration(minutes: 5);

  late SharedPreferences _prefs;
  String localTz = 'UTC';

  late HeroCity hero;
  List<CityEntry> cities = [];
  AppThemeMode themeMode = AppThemeMode.auto;

  /// tz -> absolute path of a user-supplied landmark photo, copied into app
  /// storage so it survives the picker's own (often temporary) file. When
  /// present for a city, it replaces that city's generated skyline — mirrors
  /// web/app.js's Monuments module.
  Map<String, String> monumentPhotos = {};

  Timer? _recheckTimer;

  /// What should actually be displayed: the stored list minus whichever
  /// city the hero is currently showing, so the hero is never duplicated
  /// in the strip even if it's still present in the saved preference.
  List<CityEntry> get visibleCities => cities.where((c) => c.tz != hero.tz).toList();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    try {
      localTz = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      localTz = 'UTC';
    }

    final override = _loadHeroOverride();
    hero = override ?? _deviceTzGuess();
    cities = _loadCities() ?? _defaultStrip(hero.tz);
    themeMode = _loadThemeMode();
    monumentPhotos = _loadMonuments();

    if (override == null) unawaited(_tryGeolocate());

    _recheckTimer = Timer.periodic(_geoRecheckInterval, (_) {
      if (_loadHeroOverride() == null) {
        unawaited(_tryGeolocate());
        _checkDeviceTzChanged();
      }
    });
  }

  @override
  void dispose() {
    _recheckTimer?.cancel();
    super.dispose();
  }

  HeroCity _deviceTzGuess() {
    final entry = cityForTimeZone(localTz);
    return entry != null
        ? HeroCity(name: entry.name, tz: entry.tz, source: HeroSource.deviceTz)
        : HeroCity(name: friendlyNameFromTz(localTz), tz: localTz, source: HeroSource.deviceTz);
  }

  void _checkDeviceTzChanged() async {
    if (hero.source != HeroSource.deviceTz) return;
    String fresh;
    try {
      fresh = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return;
    }
    if (fresh != localTz) {
      localTz = fresh;
      _setHero(_deviceTzGuess());
    }
  }

  Future<void> _tryGeolocate() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // the device-timezone guess already rendered — never block the UI
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // coarse location only
          timeLimit: Duration(seconds: 8),
        ),
      );
      final match = nearestCity(position.latitude, position.longitude);
      if (match != null && match.distanceKm <= _geoMaxUsefulKm) {
        _setHero(HeroCity(name: match.city.name, tz: match.city.tz, source: HeroSource.geo));
      }
      // else: too far from anything curated to trust — keep the current guess.
    } catch (_) {
      // Denied, unavailable, or timed out — the device-timezone guess
      // already rendered, so there's nothing further to do.
    }
  }

  void setManualHeroOverride(CityEntry? city) {
    if (city == null) {
      _prefs.remove(_heroOverrideKey);
      _setHero(_deviceTzGuess());
      unawaited(_tryGeolocate());
      return;
    }
    _prefs.setString(_heroOverrideKey, jsonEncode({'name': city.name, 'tz': city.tz}));
    _setHero(HeroCity(name: city.name, tz: city.tz, source: HeroSource.manual));
  }

  HeroCity? _loadHeroOverride() {
    final raw = _prefs.getString(_heroOverrideKey);
    if (raw == null) return null;
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      return HeroCity(name: parsed['name'] as String, tz: parsed['tz'] as String, source: HeroSource.manual);
    } catch (_) {
      return null;
    }
  }

  void _setHero(HeroCity next) {
    if (hero.tz == next.tz && hero.source == next.source) return;
    hero = next;
    notifyListeners();
  }

  // --- City strip -----------------------------------------------------

  List<CityEntry> _defaultStrip(String heroTz) => defaultStripTzs
      .map(cityForTimeZone)
      .whereType<CityEntry>()
      .where((c) => c.tz != heroTz)
      .toList();

  List<CityEntry>? _loadCities() {
    final raw = _prefs.getStringList(_cityStorageKey);
    if (raw == null || raw.isEmpty) return null;
    return raw.map((tz) => cityForTimeZone(tz) ?? CityEntry(name: friendlyNameFromTz(tz), tz: tz, lat: 0, lon: 0)).toList();
  }

  void _saveCities() => _prefs.setStringList(_cityStorageKey, cities.map((c) => c.tz).toList());

  /// Returns true on success, or a message if the city cap was hit.
  String? addCity(CityEntry city) {
    if (cities.any((c) => c.tz == city.tz)) return null;
    if (cities.length >= maxCities) return 'Maximum of $maxCities cities — remove one first.';
    cities.add(city);
    _saveCities();
    notifyListeners();
    return null;
  }

  /// Returns null on success, or a message if the city floor was hit.
  String? removeCity(String tz) {
    if (cities.length <= minCities) {
      return 'Minimum of $minCities cities — add another before removing.';
    }
    cities.removeWhere((c) => c.tz == tz);
    _saveCities();
    notifyListeners();
    return null;
  }

  void reorderCity(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    if (fromIndex < 0 || toIndex < 0 || fromIndex >= cities.length || toIndex >= cities.length) return;
    final moved = cities.removeAt(fromIndex);
    cities.insert(toIndex, moved);
    _saveCities();
    notifyListeners();
  }

  // --- Monument photos --------------------------------------------------

  Map<String, String> _loadMonuments() {
    final raw = _prefs.getString(_monumentStorageKey);
    if (raw == null) return {};
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, String>{};
      for (final entry in parsed.entries) {
        if (File(entry.value as String).existsSync()) result[entry.key] = entry.value as String;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  void _saveMonuments() => _prefs.setString(_monumentStorageKey, jsonEncode(monumentPhotos));

  /// Copies [sourcePath] (from the image picker, often a transient cache
  /// file) into this app's own documents directory under a name keyed by
  /// tz, so it survives restarts and OS cache cleanup. Replaces any
  /// previous photo for the same city.
  Future<void> setMonumentPhoto(String tz, String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = sourcePath.contains('.') ? sourcePath.substring(sourcePath.lastIndexOf('.')) : '.jpg';
    final safeName = tz.replaceAll('/', '_');
    final dest = '${dir.path}/monument_$safeName$ext';

    final previous = monumentPhotos[tz];
    await File(sourcePath).copy(dest);
    if (previous != null && previous != dest) {
      unawaited(File(previous).delete().catchError((_) => File(previous)));
    }

    monumentPhotos[tz] = dest;
    _saveMonuments();
    notifyListeners();
  }

  void removeMonumentPhoto(String tz) {
    final path = monumentPhotos.remove(tz);
    if (path != null) unawaited(File(path).delete().catchError((_) => File(path)));
    _saveMonuments();
    notifyListeners();
  }

  // --- Theme ------------------------------------------------------------

  AppThemeMode _loadThemeMode() {
    final raw = _prefs.getString(_themeStorageKey);
    return AppThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeMode.auto,
    );
  }

  void setThemeMode(AppThemeMode mode) {
    themeMode = mode;
    _prefs.setString(_themeStorageKey, mode.name);
    notifyListeners();
  }
}
