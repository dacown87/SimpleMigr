import 'package:flutter/material.dart';

import '../weather/weather_api.dart';
import '../weather/weather_sync.dart';

/// Ort für die Wetterdaten wählen, plus Quellenhinweis (CC BY 4.0).
class WeatherPlaceTile extends StatelessWidget {
  const WeatherPlaceTile({super.key, required this.location, required this.api});

  final LocationStore location;
  final WeatherApi api;

  Future<void> _pick(BuildContext context) async {
    final place = await showDialog<GeoPlace?>(
      context: context,
      builder: (_) => _PlaceDialog(api: api, hasPlace: location.value != null),
    );
    if (place == null) return;
    // Ein Ort mit leerem Namen bedeutet „entfernen“.
    await location.set(place.name.isEmpty ? null : place);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GeoPlace?>(
      valueListenable: location,
      builder: (context, place, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            key: const ValueKey('weather-place'),
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Ort für Wetterdaten'),
            subtitle: Text(place?.name ?? 'nicht gesetzt – kein Wetter'),
            onTap: () => _pick(context),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Text(
              'Wetter wird nur rund um Migränetage geholt. Wetterdaten von Open-Meteo.com (CC BY 4.0).',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceDialog extends StatefulWidget {
  const _PlaceDialog({required this.api, required this.hasPlace});

  final WeatherApi api;
  final bool hasPlace;

  @override
  State<_PlaceDialog> createState() => _PlaceDialogState();
}

class _PlaceDialogState extends State<_PlaceDialog> {
  final _controller = TextEditingController();
  List<GeoPlace> _results = const [];
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final r = await widget.api.searchPlaces(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _message = r.isEmpty ? 'Nichts gefunden' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _message = 'Suche fehlgeschlagen (Internet?)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ort suchen'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('place-field'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Stadt oder Ort',
                suffixIcon: IconButton(
                  key: const ValueKey('place-search'),
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
            ),
            if (_busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
            if (_message != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in _results)
                    ListTile(
                      title: Text(p.name),
                      onTap: () => Navigator.of(context).pop(p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.hasPlace)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const GeoPlace(name: '', lat: 0, lon: 0)),
            child: const Text('Entfernen'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
      ],
    );
  }
}
