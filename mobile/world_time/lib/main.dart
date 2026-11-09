import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'state/app_state.dart';
import 'widgets/city_ticker.dart';
import 'widgets/hero_clock.dart';
import 'widgets/scene_background.dart';
import 'widgets/settings_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  runApp(const WorldTimeApp());
}

class WorldTimeApp extends StatefulWidget {
  const WorldTimeApp({super.key});

  @override
  State<WorldTimeApp> createState() => _WorldTimeAppState();
}

class _WorldTimeAppState extends State<WorldTimeApp> {
  final AppState _appState = AppState();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _appState.init().then((_) => setState(() => _ready = true));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Color(0xFF0A0A0C), body: SizedBox.shrink()),
      );
    }
    return ChangeNotifierProvider.value(
      value: _appState,
      child: const _ThemedApp(),
    );
  }
}

/// Resolves the UI chrome theme (light/dark) the same way web/app.js's
/// Theme module does: auto (the hero city's current daylight), system, or a
/// direct day/night override — independent of each city's own generated
/// sky, which always reflects real local time regardless of this.
class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  bool _isLight(BuildContext context, AppState app) {
    switch (app.themeMode) {
      case AppThemeMode.day:
        return true;
      case AppThemeMode.night:
        return false;
      case AppThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.light;
      case AppThemeMode.auto:
        return skyPalette(localHourFraction(app.hero.tz)).daylight >= 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isLight = _isLight(context, app);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'World Time',
      theme: _buildTheme(isLight),
      home: const WorldTimeHome(),
    );
  }

  ThemeData _buildTheme(bool light) {
    final ink = light ? const Color(0xFF16161A) : const Color(0xFFF5F3EE);
    final scaffold = light ? Colors.white : const Color(0xFF0A0A0C);
    return ThemeData(
      useMaterial3: true,
      brightness: light ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: scaffold,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFB765),
        brightness: light ? Brightness.light : Brightness.dark,
      ),
      textTheme: Typography.englishLike2021.apply(bodyColor: ink, displayColor: ink),
    );
  }
}

class WorldTimeHome extends StatelessWidget {
  const WorldTimeHome({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final ink = theme.colorScheme.brightness == Brightness.light ? const Color(0xFF16161A) : const Color(0xFFF5F3EE);
    final inkDim = ink.withValues(alpha: 0.6);
    final cardTop = theme.colorScheme.brightness == Brightness.light ? Colors.white : const Color(0xFF1C1C1F);
    final cardBottom = theme.colorScheme.brightness == Brightness.light ? const Color(0xFFE3E3E8) : const Color(0xFF0C0C0E);
    final seam = Colors.black.withValues(alpha: theme.colorScheme.brightness == Brightness.light ? 0.14 : 0.45);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 700;
          final digitSize = isTablet ? 150.0 : (constraints.maxWidth / 7.2).clamp(60.0, 110.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Generative, per-city, day/night-aware background.
              _AnimatedScene(tz: app.hero.tz),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                    stops: const [0, 0.3, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 20, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 18, color: ink),
                              const SizedBox(width: 8),
                              Text('WORLD TIME', style: TextStyle(color: ink, fontWeight: FontWeight.w800, letterSpacing: 3, fontSize: 14)),
                            ],
                          ),
                          Row(
                            children: [
                              Text(_dateLabel(), style: TextStyle(color: inkDim, fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.settings_outlined),
                                color: ink,
                                onPressed: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: theme.scaffoldBackgroundColor,
                                  builder: (_) => const SettingsSheet(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: HeroClock(
                            tz: app.hero.tz,
                            label: '${app.hero.name} · Local',
                            cardTop: cardTop,
                            cardBottom: cardBottom,
                            seamColor: seam,
                            ink: ink,
                            inkDim: inkDim,
                            digitSize: digitSize,
                          ),
                        ),
                      ),
                      CityTicker(cities: app.visibleCities, ink: ink, inkDim: inkDim),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _dateLabel() {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

class _AnimatedScene extends StatefulWidget {
  final String tz;
  const _AnimatedScene({required this.tz});

  @override
  State<_AnimatedScene> createState() => _AnimatedSceneState();
}

class _AnimatedSceneState extends State<_AnimatedScene> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _seconds = 0;
  final _stopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      setState(() => _seconds = _stopwatch.elapsedMilliseconds / 1000);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SceneBackgroundPainter(tz: widget.tz, animationSeconds: _seconds),
      size: Size.infinite,
    );
  }
}
