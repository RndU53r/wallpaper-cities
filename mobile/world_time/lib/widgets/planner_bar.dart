import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/cities_db.dart';
import '../state/app_state.dart';

const List<String> _monthAbbr = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];
const List<String> _weekdayAbbr = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// Planner mode's control surface: drag (or tap) anywhere along the 24h
/// track to set the anchor city's time of day; every other tracked city
/// (rendered by CityTicker, not this widget) updates live to match. Mirrors
/// web/app.js's #planner bar — same interaction, same day-stepper, same
/// "NOW" exit.
class PlannerBar extends StatelessWidget {
  final Color ink;
  final Color inkDim;
  final Color accent;

  const PlannerBar({super.key, required this.ink, required this.inkDim, required this.accent});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.planningActive || app.plannerAnchorTz == null || app.plannerReferenceInstant == null) {
      return const SizedBox.shrink();
    }

    final loc = tz.getLocation(app.plannerAnchorTz!);
    final at = tz.TZDateTime.from(app.plannerReferenceInstant!, loc);
    final minutesOfDay = at.hour * 60 + at.minute;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: cityNameForTz(app.plannerAnchorTz!).toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: ink),
                      ),
                      TextSpan(
                        text: '  ·  DRAG TO SET TIME',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: inkDim),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: app.exitPlanning,
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('NOW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _DayStepper(ink: ink, inkDim: inkDim, label: '${_weekdayAbbr[at.weekday - 1]} · ${_monthAbbr[at.month - 1]} ${at.day}'),
          ),
          const SizedBox(height: 16),
          _Track(minutesOfDay: minutesOfDay, ink: ink, inkDim: inkDim, accent: accent),
        ],
      ),
    );
  }
}

class _DayStepper extends StatelessWidget {
  final Color ink;
  final Color inkDim;
  final String label;
  const _DayStepper({required this.ink, required this.inkDim, required this.label});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dayBtn(context, Icons.chevron_left, () => app.shiftPlannerDay(-1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: inkDim)),
        ),
        _dayBtn(context, Icons.chevron_right, () => app.shiftPlannerDay(1)),
      ],
    );
  }

  Widget _dayBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(padding: const EdgeInsets.all(2), child: Icon(icon, size: 18, color: ink)),
    );
  }
}

class _Track extends StatefulWidget {
  final int minutesOfDay;
  final Color ink;
  final Color inkDim;
  final Color accent;
  const _Track({required this.minutesOfDay, required this.ink, required this.inkDim, required this.accent});

  @override
  State<_Track> createState() => _TrackState();
}

class _TrackState extends State<_Track> {
  void _updateFromLocalX(double localX, double width) {
    final frac = (localX / width).clamp(0.0, 1.0);
    var minutes = ((frac * 1440) / 5).round() * 5;
    if (minutes >= 1440) minutes = 1435;
    context.read<AppState>().setPlannerTimeOfDay(minutes ~/ 60, minutes % 60);
  }

  @override
  Widget build(BuildContext context) {
    final hh = (widget.minutesOfDay ~/ 60).toString().padLeft(2, '0');
    final mm = (widget.minutesOfDay % 60).toString().padLeft(2, '0');

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fraction = widget.minutesOfDay / 1440;

        return SizedBox(
          key: const Key('plannerTrack'),
          height: 44,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // A single Pan recognizer (rather than separate Tap + Horizontal
            // Drag recognizers competing in the same gesture arena) is what
            // makes both "tap to jump" and "drag to scrub" reliably land on
            // this one handler — onPanDown fires immediately like onTapDown
            // does, with no arena ambiguity against the drag recognizer.
            onPanDown: (d) => _updateFromLocalX(d.localPosition.dx, width),
            onPanUpdate: (d) => _updateFromLocalX(d.localPosition.dx, width),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.ink.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: widget.ink.withValues(alpha: 0.14)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var h = 0; h <= 24; h += 3)
                        Text(
                          (h % 24).toString().padLeft(2, '0'),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: widget.ink.withValues(alpha: 0.28)),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: (fraction * width - 10).clamp(0.0, width - 20),
                  top: 12,
                  child: IgnorePointer(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.accent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                          ),
                          child: Text(
                            '$hh:$mm',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: widget.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
