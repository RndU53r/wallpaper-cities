import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'data/cities_db.dart';
import 'state/app_state.dart';
import 'widgets/background_brightness.dart';
import 'widgets/city_ticker.dart';
import 'widgets/hero_clock.dart';
import 'widgets/planner_bar.dart';
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

class WorldTimeHome extends StatefulWidget {
  const WorldTimeHome({super.key});

  @override
  State<WorldTimeHome> createState() => _WorldTimeHomeState();
}

class _WorldTimeHomeState extends State<WorldTimeHome> {
  // Whether the actual rendered pixels behind the ticker (sampled from the
  // real background — generated scene or a user's own photo — not guessed
  // from the Day/Night chrome theme) currently read as dark. Defaults to
  // dark, matching the generated scene's near-black building silhouettes,
  // which is what's behind the ticker before the first sample lands.
  bool _tickerOnDark = true;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final monumentPath = app.monumentPhotos[app.hero.tz];
    final theme = Theme.of(context);
    final ink = theme.colorScheme.brightness == Brightness.light ? const Color(0xFF16161A) : const Color(0xFFF5F3EE);
    final inkDim = ink.withValues(alpha: 0.6);
    final cardTop = theme.colorScheme.brightness == Brightness.light ? Colors.white : const Color(0xFF1C1C1F);
    final cardBottom = theme.colorScheme.brightness == Brightness.light ? const Color(0xFFE3E3E8) : const Color(0xFF0C0C0E);
    final seam = Colors.black.withValues(alpha: theme.colorScheme.brightness == Brightness.light ? 0.14 : 0.45);

    // Independent of the chrome theme — a dark monument photo needs light
    // ticker text even in Day theme, and vice versa.
    final tickerInk = _tickerOnDark ? const Color(0xFFF5F3EE) : const Color(0xFF16161A);
    final tickerInkDim = tickerInk.withValues(alpha: 0.78);
    final tickerShadow = [
      Shadow(
        color: (_tickerOnDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
        blurRadius: 6,
        offset: const Offset(0, 1),
      ),
    ];

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 700;
          final digitSize = isTablet ? 150.0 : (constraints.maxWidth / 7.2).clamp(60.0, 110.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // The hero city's own landmark photo if the user added one,
              // else the generative, per-city, day/night-aware background.
              BackgroundBrightnessSampler(
                onSample: (onDark) {
                  if (onDark != _tickerOnDark && mounted) setState(() => _tickerOnDark = onDark);
                },
                child: monumentPath != null
                    ? Image.file(File(monumentPath), fit: BoxFit.cover, key: ValueKey(monumentPath))
                    : _AnimatedScene(tz: app.hero.tz),
              ),
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
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, size: 18, color: ink),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'WORLD TIME',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: ink, fontWeight: FontWeight.w800, letterSpacing: 3, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dateLabel(abbreviated: !isTablet),
                                style: TextStyle(color: inkDim, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              _TopbarIconButton(
                                icon: Icons.tune,
                                tooltip: 'Compare times',
                                color: app.planningActive ? theme.colorScheme.onPrimary : ink,
                                background: app.planningActive ? theme.colorScheme.primary : null,
                                onPressed: () => app.planningActive ? app.exitPlanning() : app.enterPlanning(),
                              ),
                              _TopbarIconButton(
                                icon: Icons.settings_outlined,
                                tooltip: 'City settings',
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
                            tz: app.planningActive ? app.plannerAnchorTz! : app.hero.tz,
                            label: app.planningActive
                                ? '${cityNameForTz(app.plannerAnchorTz!)} · Set Time'
                                : '${app.hero.name} · Local',
                            cardTop: cardTop,
                            cardBottom: cardBottom,
                            seamColor: seam,
                            ink: ink,
                            inkDim: inkDim,
                            digitSize: digitSize,
                            overrideInstant: app.planningActive ? app.plannerReferenceInstant : null,
                          ),
                        ),
                      ),
                      if (app.planningActive) PlannerBar(ink: ink, inkDim: inkDim, accent: theme.colorScheme.primary),
                      CityTicker(
                        cities: app.visibleCities,
                        ink: tickerInk,
                        inkDim: tickerInkDim,
                        textShadows: tickerShadow,
                        accent: theme.colorScheme.primary,
                        overrideInstant: app.planningActive ? app.plannerReferenceInstant : null,
                        anchorTz: app.planningActive ? app.plannerAnchorTz : null,
                        onCityTap: app.planningActive ? app.setPlannerAnchor : null,
                      ),
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

  String _dateLabel({bool abbreviated = false}) {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    // The phone-width topbar is tight once the compare-times and settings
    // icons are both present — "Tue, Nov 10" instead of the full
    // "Tuesday, November 10" is what keeps that row from overflowing.
    if (abbreviated) {
      return '${weekdays[now.weekday - 1].substring(0, 3)}, ${months[now.month - 1].substring(0, 3)} ${now.day}';
    }
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

/// A smaller-footprint IconButton for the topbar — the default IconButton's
/// 48x48 minimum tap target is what pushed the phone-width topbar row into
/// overflow once a second icon joined the settings gear.
class _TopbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color? background;
  final VoidCallback onPressed;

  const _TopbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      color: color,
      style: IconButton.styleFrom(
        backgroundColor: background,
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
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
