import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/cities_db.dart';
import '../state/app_state.dart';

/// The city/hero/theme editor, opened as a modal bottom sheet. Mirrors
/// web/app.js's Panel: hero override row, theme picker, search-to-add, and
/// a reorderable, bounded (4-6) city list.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final _searchController = TextEditingController();
  List<CityEntry> _results = [];

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _results = citiesDb.where((c) => c.name.toLowerCase().contains(q) || c.tz.toLowerCase().contains(q)).take(8).toList();
    });
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('CITIES', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 8),
              _heroRow(app, theme),
              const SizedBox(height: 10),
              _themeRow(app, theme),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Search a city or timezone (e.g. Berlin, Asia/Dubai)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_results.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(8)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final c = _results[i];
                      return ListTile(
                        dense: true,
                        title: Text(c.name),
                        subtitle: Text(c.tz, style: theme.textTheme.bodySmall),
                        onTap: () {
                          final err = app.addCity(c);
                          if (err != null) {
                            _showMessage(err);
                          } else {
                            _searchController.clear();
                            setState(() => _results = []);
                          }
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: scrollController,
                  itemCount: app.cities.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    app.reorderCity(oldIndex, newIndex);
                  },
                  itemBuilder: (context, i) {
                    final city = app.cities[i];
                    final atMin = app.cities.length <= AppState.minCities;
                    return ListTile(
                      key: ValueKey(city.tz),
                      dense: true,
                      leading: const Icon(Icons.drag_handle, size: 20),
                      title: Text(city.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(city.tz, style: theme.textTheme.bodySmall),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.star_outline, size: 20),
                            tooltip: 'Set as hero city',
                            onPressed: () => app.setManualHeroOverride(city),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            tooltip: atMin ? 'Minimum of ${AppState.minCities} cities' : 'Remove',
                            onPressed: atMin
                                ? null
                                : () {
                                    final err = app.removeCity(city.tz);
                                    if (err != null) _showMessage(err);
                                  },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Changes apply immediately. Drag to reorder. 4-6 cities.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroRow(AppState app, ThemeData theme) {
    final sourceLabel = switch (app.hero.source) {
      HeroSource.manual => 'manual',
      HeroSource.geo => 'auto — location',
      HeroSource.deviceTz => 'auto — device timezone',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HERO CITY', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
                Text('${app.hero.name} ($sourceLabel)', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (app.hero.source == HeroSource.manual)
            TextButton(onPressed: () => app.setManualHeroOverride(null), child: const Text('Use automatic')),
        ],
      ),
    );
  }

  Widget _themeRow(AppState app, ThemeData theme) {
    Widget modeButton(AppThemeMode mode, String label) {
      final active = app.themeMode == mode;
      return ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => app.setThemeMode(mode),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        modeButton(AppThemeMode.auto, 'Auto (daylight)'),
        modeButton(AppThemeMode.system, 'System'),
        modeButton(AppThemeMode.day, 'Day'),
        modeButton(AppThemeMode.night, 'Night'),
      ],
    );
  }
}
